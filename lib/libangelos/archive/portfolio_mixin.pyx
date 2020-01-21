# cython: language_level=3
#
# Copyright (c) 2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Mixin for enforcing portfolio policy's before importing."""
import asyncio
import copy
import functools
import logging
import uuid
from typing import Tuple, List, Set, Any

import msgpack
from libangelos.error import Error
from libangelos.archive7 import Entry
from libangelos.document.entities import Entity
from libangelos.document.types import EntityT, StatementT, DocumentT
from libangelos.helper import Glue
from libangelos.policy.accept import ImportPolicy, ImportUpdatePolicy
from libangelos.policy.portfolio import PortfolioPolicy, DOCUMENT_PATH, PrivatePortfolio, PORTFOLIO_PATTERN, Portfolio, \
    PField, PGroup, DocSet
from libangelos.utils import Util


class PortfolioMixin:
    """Mixin that lets a storage deal with a portfolio repository."""

    PATH_PORTFOLIOS = ("/portfolios/",)

    async def update_portfolio(
        self, portfolio: Portfolio
    ) -> Tuple[bool, Set[DocumentT], Set[DocumentT]]:
        """Update a portfolio in storage with documents.

        This method applies policys while doing document comparison.

        Parameters
        ----------
        portfolio : Portfolio
            Portfolio to update storage with.

        Returns
        -------
        Tuple[bool, Set[DocumentT], Set[DocumentT]]
            Tuple of bool and two Set of documents.

            [0] boolean indicating success or failure.
            [2] set with rejected documents
            [3] set of removed documents

        """
        old = await self.load_portfolio(portfolio.entity.id, PGroup.ALL)

        issuer, owner = portfolio.to_sets()
        new_set = issuer | owner

        issuer, owner = old.to_sets()
        old_set = issuer | owner

        newdoc = set()
        upddoc = set()
        for ndoc in new_set:  # Find documents that are new or changed.
            newone = True
            updone = False
            for odoc in old_set:
                if ndoc.id == odoc.id:
                    newone = False
                    if ndoc.expires != odoc.expires:
                        updone = True
            if newone:
                newdoc.add(ndoc)
            elif updone:
                upddoc.add(ndoc)

        new = Portfolio()
        # Setting entity manually is required in case it is the same document
        # Old entity will be overridden if there is a newer
        new.entity = old.entity
        new.from_sets(newdoc | upddoc, newdoc | upddoc)
        rejected = set()

        # Validating any new keys
        imp_policy = ImportPolicy(old)
        upd_policy = ImportUpdatePolicy(old)
        if new.keys and old.keys:
            for key in new.keys:
                reject = set()
                if not upd_policy.keys(key):
                    rejected.add(key)
            new.keys -= reject
            old.keys += new.keys  # Adding new keys to old portfolio,
            # this way the old portfolio can verify documents signed with
            # new keys.
            rejected |= reject

        # Validating any new entity
        if new.entity and old.entity:
            if not upd_policy.entity(new.entity):
                new.entity = None

        # Adding old entity and keys if none.
        if not new.entity:
            new.entity = old.entity
        if not new.keys:
            new.keys = old.keys

        if new.profile:
            if not imp_policy.issued_document(new.profile):
                rejected.add(new.profile)
                new.profile = None
        if new.network:
            if not imp_policy.issued_document(new.network):
                rejected.add(new.network)
                new.network = None

        if new.issuer.verified:
            for verified in new.issuer.verified:
                rejected = set()
                if not imp_policy.issued_document(verified):
                    reject.add(verified)
            new.issuer.verified -= reject
            rejected |= reject
        if new.issuer.trusted:
            for trusted in new.issuer.trusted:
                reject = set()
                if not imp_policy.issued_document(trusted):
                    rejected.add(trusted)
            new.issuer.trusted -= reject
            rejected |= reject
        if new.issuer.revoked:
            for revoked in new.issuer.revoked:
                reject = set()
                if not imp_policy.issued_document(revoked):
                    rejected.add(revoked)
            new.issuer.revoked -= reject
            rejected |= reject

        removed = (
            portfolio.owner.revoked
            | portfolio.owner.trusted
            | portfolio.owner.verified
        )

        # Really remove files that can't be verified
        portfolio.owner.revoked = set()
        portfolio.owner.trusted = set()
        portfolio.owner.verified = set()

        if hasattr(new, "privkeys"):
            if new.privkeys:
                if not imp_policy.issued_document(new.privkeys):
                    new.privkeys = None
        if hasattr(new, "domain"):
            if new.domain:
                if not imp_policy.issued_document(new.domain):
                    new.domain = None
        if hasattr(new, "nodes"):
            if new.nodes:
                for node in new.nodes:
                    reject = set()
                    if not imp_policy.node_document(node):
                        reject.add(node)
                new.nodes -= reject
                rejected |= reject

        return await self.save_portfolio(new), rejected, removed

    async def add_portfolio(
        self, portfolio: Portfolio
    ) -> Tuple[bool, Set[DocumentT], Set[DocumentT]]:
        """Import a portfolio of douments into the vault.

        All policies are being applied, invalid documents or documents that
        require extra portfolios for validation are rejected. That includes
        the owner documents.

        Return whether portfolio was imported True/False and rejected documents
        and removed documents.

        Parameters
        ----------
        portfolio : Portfolio
            Portfolio to be imported.

        Tuple[bool, Set[DocumentT], Set[DocumentT]]
            Tuple of bool and two Set of documents.

            [0] boolean indicating success or failure.
            [2] set with rejected documents
            [3] set of removed documents

        """
        rejected = set()
        portfolio = copy.copy(portfolio)
        policy = ImportPolicy(portfolio)

        entity, keys = policy.entity()
        if (entity, keys) == (None, None):
            logging.error("Portfolio entity and keys doesn't validate")
            return False, None, None

        rejected |= policy._filter_set(portfolio.keys)
        portfolio.keys.add(keys)

        if portfolio.profile and not policy.issued_document(portfolio.profile):
            rejected.add(portfolio.profile)
            portfolio.profile = None
            logging.warning("Removed invalid profile from portfolio")

        if portfolio.network and not policy.issued_document(portfolio.network):
            rejected.add(portfolio.network)
            portfolio.network = None
            logging.warning("Removed invalid network from portfolio")

        rejected |= policy._filter_set(portfolio.issuer.revoked)
        rejected |= policy._filter_set(portfolio.issuer.verified)
        rejected |= policy._filter_set(portfolio.issuer.trusted)

        if isinstance(portfolio, PrivatePortfolio):
            if portfolio.privkeys and not policy.issued_document(
                portfolio.privkeys
            ):
                rejected.add(portfolio.privkeys)
                portfolio.privkeys = None
                logging.warning("Removed invalid private keys from portfolio")

            if portfolio.domain and not policy.issued_document(
                portfolio.domain
            ):
                rejected.add(portfolio.domain)
                portfolio.domain = None
                logging.warning("Removed invalid domain from portfolio")

            for node in portfolio.nodes:
                if node and not policy.node_document(node):
                    rejected.add(node)
                    portfolio.nodes.remove(node)
                    logging.warning("Removed invalid node from portfolio")

        removed = (
            portfolio.owner.revoked
            | portfolio.owner.trusted
            | portfolio.owner.verified
        )

        # Really remove files that can't be verified
        portfolio.owner.revoked = set()
        portfolio.owner.trusted = set()
        portfolio.owner.verified = set()

        result = await self.import_portfolio(portfolio)
        return result, rejected, removed

    async def docs_to_portfolio(
        self, documents: Set[DocumentT]
    ) -> Tuple[Set[StatementT], List[Any]]:
        """Import a bunch of statements to several portfolios.

        This method applies policys except revoked.

        Parameters
        ----------
        documents : Set[StatementT]
            Set of statement documents.

        Returns
        -------
        Tuple[Set[StatementT], List[Any]]
            [0] Set of rejected statements.
            [1] List of results from asyncio gather.

        """
        documents = DocSet(documents)
        rejected = set()

        ops = []
        for issuer_id in documents.issuers():
            policy = ImportPolicy(
                await self.load_portfolio(
                    issuer_id, PGroup.VERIFIER_REVOKED
                )
            )
            for document in documents.get_issuer(issuer_id):
                if not Util.is_typing(document, StatementT):
                    raise Util.exception(Error.PORTFOLIO_NOT_STATEMENT, {
                        "document": document.id, "issuer": document.issuer})
                if policy.issued_document(document):
                    ops.append(
                        self.save(
                            DOCUMENT_PATH[document.type].format(
                                dir="{0}{1}".format(self.PATH_PORTFOLIOS[0], document.owner),
                                file=document.id,
                            ),
                            document,
                        )
                    )
                else:
                    rejected.add(document)

        result = await self.gather(*ops)
        return rejected, result

    async def list_portfolios(self) -> Set[Tuple[str, uuid.UUID]]:
        """Load a list of all portfolios.

        Returns (List[Tuple[str, uuid.UUID]]):
            List of tuples with portfolio path and ID.

        """
        result = await self.search(
            self.PATH_PORTFOLIOS[0] + "*/*.ent",
            link=True,
            limit=None,
            deleted=False,
            fields=lambda name, entry: (name,) # entry.owner)
        )
        return set(result.keys())

    async def import_portfolio(self, portfolio: Portfolio) -> bool:
        """Save a portfolio for the first time.

        This method expects policy's to already be applied.

        Parameters
        ----------
        portfolio : Portfolio
            Portfolio to be imported.

        Returns
        -------
        bool
            Success or failure.

        """
        dirname = "{0}{1}".format(self.PATH_PORTFOLIOS[0], portfolio.entity.id)
        if self.archive.isdir(dirname):
            raise Util.exception(Error.PORTFOLIO_ALREADY_EXISTS, {
                "portfolio": portfolio.entity.id})

        await self.archive.mkdir(dirname)

        files = list()
        issuer, owner = portfolio.to_sets()
        for doc in issuer | owner:
            files.append(
                (DOCUMENT_PATH[doc.type].format(dir=dirname, file=doc.id), doc)
            )

        ops = list()
        for doc in files:
            created, updated, owner = Glue.doc_save(doc[1])
            ops.append(self.archive.mkfile(
                    filename=doc[0],
                    data=PortfolioPolicy.serialize(doc[1]),
                    id=doc[1].id,
                    created=created,
                    modified=updated,
                    owner=owner,
                    compression=Entry.COMP_NONE
                )
            )

        return await self.gather(*ops)

    async def load_portfolio(
        self, eid: uuid.UUID, config: Tuple[str]
    ) -> Portfolio:
        """Load portfolio based on uuid.

        Parameters
        ----------
        eid : uuid.UUID
            Entity ID for portfolio to load.
        config : Tuple[str]
            Which portfolio configuration to use.

        Returns
        -------
        Portfolio
            Loaded portfolio object.

        """
        dirname = "{0}{1}".format(self.PATH_PORTFOLIOS[0], eid)
        if not self.archive.isdir(dirname):
            raise Util.exception(Error.PORTFOLIO_EXISTS_NOT, {
                "portfolio": eid})

        result = await self.archive.glob(name="{0}/*".format(dirname), owner=eid)

        files = set()
        for field in config:
            pattern = PORTFOLIO_PATTERN[field]
            for filename in result:
                if pattern == filename[-4:]:
                    files.add(filename)

        ops = list()
        loop = asyncio.get_running_loop()
        for doc in files:
            ops.append(self.archive.load(filename=doc))

        results = await asyncio.gather(*ops, return_exceptions=True)

        issuer = set()
        owner = set()
        for data in results:
            if isinstance(data, Exception):
                logging.warning("Failed to load document: %s" % data)
                logging.error(data, exc_info=True)
                continue

            document = PortfolioPolicy.deserialize(data)

            if document.issuer != eid:
                owner.add(document)
            else:
                issuer.add(document)

        if PField.PRIVKEYS in config:
            portfolio = PrivatePortfolio()
        else:
            portfolio = Portfolio()

        portfolio.from_sets(issuer, owner)
        return portfolio

    async def reload_portfolio(
        self, portfolio: PrivatePortfolio, config: Tuple[str]
    ) -> bool:
        """Synchronize portfolio from storage.

        Parameters
        ----------
        portfolio : PrivatePortfolio
            Portfolio to synchronize or complement.
        config : Tuple[str]
            Which portfolio configuration to use.

        Returns
        -------
        bool
            Success or failure.

        """
        dirname = "{0}{1}".format(self.PATH_PORTFOLIOS[0], portfolio.entity.id)
        if not self.archive.isdir(dirname):
            raise Util.exception(Error.PORTFOLIO_EXISTS_NOT, {
                "portfolio": portfolio.entity.id})

        result = await self.archive.glob(
            name="{dir}/*".format(dirname), owner=portfolio.entity.id
        )

        files = set()
        for field in config:
            pattern = PORTFOLIO_PATTERN[field]
            for filename in result:
                if pattern == filename[-4:]:
                    files.add(filename)

        available = set()
        for filename in files:
            available.add(PortfolioPolicy.path2fileident(filename))

        issuer, owner = portfolio.to_sets()
        loaded = set()
        for doc in issuer + owner:
            loaded.add(PortfolioPolicy.doc2fileident(doc))

        toload = available - loaded
        files2 = set()
        for filename in files:
            if PortfolioPolicy.path2fileident(filename) not in toload:
                files2.add(filename)

        files = files - files2

        ops = list()
        for doc in files:
            ops.append(self.archive.load(filename=doc))

        results = await asyncio.gather(*ops, return_exceptions=True)

        issuer = set()
        owner = set()
        for data in results:
            if isinstance(data, Exception):
                logging.warning("Failed to load document: %s" % data)
                continue

            document = PortfolioPolicy.deserialize(data)

            if document.issuer != portfolio.entity.id:
                owner.add(document)
            else:
                issuer.add(document)

        portfolio.from_sets(issuer, owner)
        return portfolio

    async def save_portfolio(self, portfolio: PrivatePortfolio) -> bool:
        """Save a changed portfolio.

        This method expects policies to be applied."""
        dirname = "{0}{1}".format(self.PATH_PORTFOLIOS[0], portfolio.entity.id)
        if not self.archive.isdir(dirname):
            raise Util.exception(Error.PORTFOLIO_EXISTS_NOT, {
                "portfolio": portfolio.entity.id})

        files = await self.archive.glob(
            name="{dir}/*".format(dir=dirname), owner=portfolio.entity.id
        )

        ops = list()
        save, _ = portfolio.to_sets()

        loop = asyncio.get_running_loop()
        for doc in save:
            filename = DOCUMENT_PATH[doc.type].format(dir=dirname, file=doc.id)
            if filename in files:
                ops.append(
                   self.archive.save(
                        filename=filename,
                        data=msgpack.packb(
                            doc.export_bytes(),
                            use_bin_type=True,
                            strict_types=True,
                        ),
                        compression=Entry.COMP_NONE
                    )
                )
            else:
                created, updated, owner = Glue.doc_save(doc)
                ops.append(
                    self.archive.mkfile(
                        filename=filename,
                        data=PortfolioPolicy.serialize(doc),
                        id=doc.id,
                        created=created,
                        updated=updated,
                        owner=owner,
                        compression=Entry.COMP_NONE,
                    )
                )

        return await self.gather(*ops)

    async def delete_portfolio(self, eid: uuid.UUID) -> bool:
        """Delete an existing portfolio, except the owner.

        Args:
            eid (uuid.UUID):
                The portfolio entity ID.

        Returns (bool):
            True upon success.

        """
        if eid == self.facade.data.portfolio.entity.id:
            raise RuntimeError("Illegal operation, trying to delete owning entity!")

        dirname = "{0}{1}".format(self.PATH_PORTFOLIOS[0], eid)
        if not self.archive.isdir(dirname):
            raise Util.exception(Error.PORTFOLIO_EXISTS_NOT, {
                "portfolio": eid})

        files = await self.archive.glob(name="{dir}/*".format(dir=dirname))

        result = True
        ops = list()
        for filename in files:
            ops.append(self.archive.remove(filename=filename, mode=3))
        result = result if await self.gather(*ops) else False
        result = result if await self.archive.remove(filename=dirname, mode=3) else False
        return result
