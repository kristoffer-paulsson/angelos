# cython: language_level=3
#
# Copyright (c) 2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Mixin for enforcing portfolio policy's before importing."""
import asyncio
import copy
import logging
import uuid
from typing import Tuple, List, Set, Any

from libangelos.archive7 import Entry
from libangelos.document.types import StatementT, DocumentT
from libangelos.error import Error
from libangelos.helper import Glue
from libangelos.policy.accept import EntityKeysPortfolioValidatePolicy, IssuedDocumentPortfolioValidatePolicy, \
    NodePortfolioValidatePolicy, ImportPolicy, ProfileUpdatePortfolioPolicy, NetworkUpdatePortfolioPolicy, \
    StatementImportPortfolioPolicy, EntityUpdatePortfolioPolicy, PrivateKeysImportPortfolioPolicy, \
    NodeUpdatePortfolioPolicy, DomainUpdatePortfolioPolicy
from libangelos.policy.portfolio import PortfolioPolicy, DOCUMENT_PATH, PrivatePortfolio, PORTFOLIO_PATTERN, Portfolio, \
    PField, PGroup, DocSet
from libangelos.utils import Util

from policy.accept import KeysImportPortfolioPolicy


class PortfolioMixin:
    """Mixin that lets a storage deal with a portfolio repository."""

    PATH_PORTFOLIOS = ("/portfolios/",)

    def portfolio_path(self, eid: uuid.UUID) -> str:
        """Generate portfolio path for a particular entity id."""
        return  "{0}{1}".format(self.PATH_PORTFOLIOS[0], eid)

    async def portfolio_files(self, path: str, owner: uuid.UUID = None):
        """Glob a list of all files in a portfolio."""
        return await self.archive.glob(name="{dir}/*".format(dir=path), owner=owner)

    def portfolio_exists_not(self, path: str, eid: uuid.UUID):
        """Check that portfolio exists."""
        if not self.archive.isdir(path):
            raise Util.exception(Error.PORTFOLIO_EXISTS_NOT, {
                "portfolio": eid})

    def write_file(self, filename: str, doc: DocumentT):
        """Write a document to the current archive."""
        if self.archive.isfile(filename):
           return self.archive.save(
                filename=filename,
                data=PortfolioPolicy.serialize(doc),
                compression=Entry.COMP_NONE
            )
        else:
            created, updated, owner = Glue.doc_save(doc)
            return self.archive.mkfile(
                filename=filename,
                data=PortfolioPolicy.serialize(doc),
                id=doc.id,
                created=created,
                modified=updated,
                owner=owner,
                compression=Entry.COMP_NONE,
            )

    async def update_portfolio( # FIXME: Make sure it follows policy
        self, portfolio: Portfolio
    ) -> Tuple[bool, Set[DocumentT], Set[DocumentT]]:
        """Update a portfolio in storage with documents.

        This method applies policys while doing document comparison.

        Parameters
        ----------
        portfolio_temp : Portfolio
            Portfolio to update storage with.

        Returns
        -------
        Tuple[bool, Set[DocumentT], Set[DocumentT]]
            Tuple of bool and two Set of documents.

            [0] boolean indicating success or failure.
            [2] set with rejected documents
            [3] set of removed documents

        """
        updating_portfolio = copy.deepcopy(portfolio)

        # Begin checking that the entity and latest public keys validates.
        validator = EntityKeysPortfolioValidatePolicy(updating_portfolio)
        report = validator.validate()
        if not report:
            raise RuntimeError("Portfolio entity and keys doesn't validate")

        original_portfolio = await self.load_portfolio(updating_portfolio.entity.id, PGroup.ALL)

        # Get all keys that differs from updating portfolio
        keys = updating_portfolio.keys - original_portfolio.keys

        validator = KeysImportPortfolioPolicy(original_portfolio)
        report = validator.validate_all(keys)
        if not report:
            raise RuntimeError("Some of the new keys didn't validate.")


        validator = EntityUpdatePortfolioPolicy(original_portfolio)
        report = validator.validate_all(updating_portfolio.entity)
        if not report:
            raise RuntimeError("The new entity didn't validate.")

        if updating_portfolio.profile:
            validator = ProfileUpdatePortfolioPolicy(original_portfolio)
            report = validator.validate_all(updating_portfolio.profile)
            if not report:
                raise RuntimeError("The new profile didn't validate.")

        if updating_portfolio.network:
            validator = NetworkUpdatePortfolioPolicy(original_portfolio)
            report = validator.validate_all(updating_portfolio.network)
            if not report:
                raise RuntimeError("The new profile didn't validate.")

        validator = StatementImportPortfolioPolicy(original_portfolio)
        report = validator.validate_all(
            updating_portfolio.issuer.revoked | updating_portfolio.issuer.trusted | updating_portfolio.issuer.verified
        )
        if not report:
            raise RuntimeError("The new statements didn't validate.")

        original_portfolio.owner.revoked = set()
        original_portfolio.owner.trusted = set()
        original_portfolio.owner.verified = set()

        if isinstance(updating_portfolio, PrivatePortfolio) and isinstance(original_portfolio, PrivatePortfolio):
            if updating_portfolio.privkeys:
                validator = PrivateKeysImportPortfolioPolicy(original_portfolio)
                report = validator.validate_all(updating_portfolio.privkeys)
                if not report:
                    raise RuntimeError("The new private key didn't validate.")

            if updating_portfolio.domain:
                validator = DomainUpdatePortfolioPolicy(original_portfolio)
                report = validator.validate_all(updating_portfolio.domain)
                if not report:
                    raise RuntimeError("The new private key didn't validate.")

            if updating_portfolio.nodes:
                validator = NodeUpdatePortfolioPolicy(original_portfolio)
                report = validator.validate_all(updating_portfolio.nodes)
                if not report:
                    raise RuntimeError("The new private key didn't validate.")

        return await self.save_portfolio(original_portfolio), set(), set()





        # Verify changes in entity according to policy.



        # ...
        # issuer, owner = updating_portfolio.to_sets()
        # new_set = issuer | owner

        # issuer, owner = original_portfolio.to_sets()
        # old_set = issuer | owner

        # newdoc = set()
        # upddoc = set()
        # for ndoc in new_set:  # Find documents that are new or changed.
        #    newone = True
        #    updone = False
        #    for odoc in old_set:
        #        if ndoc.id == odoc.id:
        #            newone = False
        #            if ndoc.expires != odoc.expires:
        #                updone = True
        #    if newone:
        #        newdoc.add(ndoc)
        #    elif updone:
        #        upddoc.add(ndoc)

        # new = Portfolio()
        # Setting entity manually is required in case it is the same document
        # Old entity will be overridden if there is a newer
        # new.entity = original_portfolio.entity
        # new.from_sets(newdoc | upddoc, newdoc | upddoc)
        # rejected = set()

        # Validating any new keys
        # imp_policy = ImportPolicy(original_portfolio)
        # upd_policy = ImportUpdatePolicy(original_portfolio)
        # if new.keys and original_portfolio.keys:
        #    for key in new.keys:
        #        reject = set()
        #        if not upd_policy.keys(key):
        #            reject.add(key)
        #    new.keys -= reject
        #    original_portfolio.keys += new.keys  # Adding new keys to old portfolio,
            # this way the old portfolio can verify documents signed with
            # new keys.
        #    rejected |= reject


        # Validating any new entity
        # if new.entity and original_portfolio.entity:
        #    if not upd_policy.entity(new.entity):
        #        new.entity = None

        # Adding old entity and keys if none.
        # if not new.entity:
        #     new.entity = original_portfolio.entity
        # if not new.keys:
        #    new.keys = original_portfolio.keys

        # if new.profile:
        #    if not imp_policy.issued_document(new.profile):
        #        rejected.add(new.profile)
        #        new.profile = None

        # if new.network:
        #    if not imp_policy.issued_document(new.network):
        #        rejected.add(new.network)
        #        new.network = None

        # if new.issuer.verified:
        #    for verified in new.issuer.verified:
        #        reject = set()
        #        if not imp_policy.issued_document(verified):
        #            reject.add(verified)
        #    new.issuer.verified -= reject
        #    rejected |= reject
        # if new.issuer.trusted:
        #    for trusted in new.issuer.trusted:
        #        reject = set()
        #        if not imp_policy.issued_document(trusted):
        #            reject.add(trusted)
        #    new.issuer.trusted -= reject
        #    rejected |= reject
        # if new.issuer.revoked:
        #    for revoked in new.issuer.revoked:
        #        reject = set()
        #        if not imp_policy.issued_document(revoked):
        #            reject.add(revoked)
        #    new.issuer.revoked -= reject
        #    rejected |= reject

        # removed = (
        #        updating_portfolio.owner.revoked
        #        | updating_portfolio.owner.trusted
        #        | updating_portfolio.owner.verified
        # )

        # Really remove files that can't be verified
        # updating_portfolio.owner.revoked = set()
        # updating_portfolio.owner.trusted = set()
        # updating_portfolio.owner.verified = set()


        # if hasattr(new, "privkeys"):
        #    if new.privkeys:
        #        if not imp_policy.issued_document(new.privkeys):
        #            new.privkeys = None
        # if hasattr(new, "domain"):
        #    if new.domain:
        #        if not imp_policy.issued_document(new.domain):
        #            new.domain = None
        # if hasattr(new, "nodes"):
        #    if new.nodes:
        #        for node in new.nodes:
        #            reject = set()
        #            if not imp_policy.node_document(node):
        #                reject.add(node)
        #        new.nodes -= reject
        #        rejected |= reject

        # return await self.save_portfolio(new), rejected, removed


    async def add_portfolio(  # FIXME: Make sure it follows policy
        self, portfolio: Portfolio
    ) -> Tuple[bool, Set[DocumentT], Set[DocumentT]]:
        """Add a new portfolio of documents into the vault.

        All policies are being applied, if documents are invalid exceptions are thrown.
        The owner documents are excluded.

        Return whether portfolio was added True/False and two empty sets.

        Parameters
        ----------
        portfolio_temp : Portfolio
            Portfolio to be imported.

        Tuple[bool, Set[DocumentT], Set[DocumentT]]
            Tuple of bool and two Set of documents.

            [0] boolean indicating success or failure.
            [2] set with rejected documents
            [3] set of removed documents

        """
        additional_portfolio = copy.deepcopy(portfolio)

        # Begin checking that the entity and latest public keys validates.
        validator = EntityKeysPortfolioValidatePolicy(additional_portfolio)
        report = validator.validate()
        if not report:
            raise RuntimeError("Portfolio entity and keys doesn't validate")

        # Check all the documents without special constraints.
        docs = set()
        docs |= additional_portfolio.keys
        docs |= additional_portfolio.issuer.revoked
        docs |= additional_portfolio.issuer.verified
        docs |= additional_portfolio.issuer.trusted
        if additional_portfolio.profile: docs.add(additional_portfolio.profile)
        if additional_portfolio.network: docs.add(additional_portfolio.network)

        validator = IssuedDocumentPortfolioValidatePolicy(additional_portfolio)
        report = validator.validate_all(docs)
        if not report:
            raise RuntimeError("Some of the portfolios issued documents didn't validate.")

        # Private portfolio section
        if isinstance(additional_portfolio, PrivatePortfolio):
            # Check all documents that are private portfolio specific without special constraints.
            docs = set()
            if additional_portfolio.privkeys: docs.add(additional_portfolio.privkeys)
            if additional_portfolio.domain: docs.add(additional_portfolio.domain)

            report = validator.validate_all(docs)
            if not report:
                raise RuntimeError("Some of the portfolios issued documents didn't validate.")

            # Check the nodes of the portfolio.
            validator = NodePortfolioValidatePolicy(additional_portfolio)
            report = validator.validate_all(additional_portfolio.nodes)
            if not report:
                raise RuntimeError("Some of the portfolios nodes didn't validate.")

        # Really remove files that can't be verified
        additional_portfolio.owner.revoked = set()
        additional_portfolio.owner.trusted = set()
        additional_portfolio.owner.verified = set()

        return await self.import_portfolio(additional_portfolio), set(), set() # Rejected and Removed ain't used any more

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
            for doc in documents.get_issuer(issuer_id):
                if not Util.is_typing(doc, StatementT):
                    raise Util.exception(Error.PORTFOLIO_NOT_STATEMENT, {
                        "document": doc.id, "issuer": doc.issuer})
                if policy.issued_document(doc):
                    filename = DOCUMENT_PATH[doc.type].format(
                        dir="{0}{1}".format(self.PATH_PORTFOLIOS[0], doc.owner),
                        file=doc.id,
                    )
                    ops.append(self.write_file(filename, doc))
                else:
                    rejected.add(doc)

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
        dirname = self.portfolio_path(portfolio.entity.id)
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
        dirname = self.portfolio_path(eid)
        self.portfolio_exists_not(dirname, eid)

        result = await self.portfolio_files(dirname, owner=eid)

        files = set()
        for field in config:
            pattern = PORTFOLIO_PATTERN[field]
            for filename in result:
                if pattern == filename[-4:]:
                    files.add(filename)

        ops = list()
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
        eid = portfolio.entity.id
        dirname = self.portfolio_path(eid)
        self.portfolio_exists_not(dirname, eid)

        result = await self.portfolio_files(dirname, owner=eid)

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
        for doc in issuer | owner:
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

            if document.issuer != eid:
                owner.add(document)
            else:
                issuer.add(document)

        portfolio.from_sets(issuer, owner)
        return portfolio

    async def save_portfolio(self, portfolio: PrivatePortfolio) -> bool:
        """Save a changed portfolio.

        This methods simply sorts all the documents from a portfolio into issued and owned documents.
        The owned documents are thrown away while the issued documents are compared to the list of existing document.
        Existing documents are updated, while the new files are created.

        This method expects policies to be applied."""
        dirname = self.portfolio_path(portfolio.entity.id)
        self.portfolio_exists_not(dirname, portfolio.entity.id)

        files = await self.portfolio_files(dirname)

        ops = list()
        issuer, owner = portfolio.to_sets()
        save = issuer | owner

        for doc in save:
            filename = DOCUMENT_PATH[doc.type].format(dir=dirname, file=doc.id)
            ops.append(self.write_file(filename, doc))

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
            raise Util.exception(Error.PORTFOLIO_ILLEGAL_DELETE, {
                "portfolio": eid})

        dirname = self.portfolio_path(eid)
        self.portfolio_exists_not(dirname, eid)

        files = await self.portfolio_files(dirname)

        result = True
        ops = list()
        for filename in files:
            ops.append(self.archive.remove(filename=filename, mode=3))
        return await self.gather(*ops)
