# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Layout for new Facade framework."""
import asyncio
import copy
import logging
import uuid
from typing import Sequence, Set, List, Tuple

from document.types import StatementT, EntityT
from utils import Util
from ..helper import Glue
from ..policy.accept import ImportPolicy, ImportUpdatePolicy
from ..policy.portfolio import DOCUMENT_PATH, PGroup, DocSet, PrivatePortfolio, Portfolio
from ..policy.types import DocumentT

from .api import ApiFacadeExtension


class PortfolioApi(ApiFacadeExtension):
    """API for portfolio interaction."""
    async def load(
        self, eid: uuid.UUID, conf: Sequence[str]
    ) -> Portfolio:
        """Load a portfolio belonging to id according to configuration."""
        return await self.facade.archive.vault.load_portfolio(eid, conf)

    async def update(
        self, portfolio: Portfolio
    ) -> (bool, Set[DocumentT], Set[DocumentT]):
        """Update a portfolio by comparison."""
        old = await self.facade.archive.vault.load_portfolio(portfolio.entity.id, PGroup.ALL)

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

        return await self.facade.archive.vault.save_portfolio(new), rejected, removed

    async def save(
        self, portfolio: Portfolio
    ) -> (bool, Set[DocumentT], Set[DocumentT]):
        """
        Import a portfolio of douments into the vault.

        All policies are being applied, invalid documents or documents that
        require extra portfolios for validation are rejected. That includes
        the owner documents.

        Return whether portfolio was imported True/False and rejected documents
        and removed documents.
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

        result = await self._vault.new_portfolio(portfolio)
        return result, rejected, removed

    async def add_docs(
        self, documents: Set[DocumentT]
    ) -> Set[DocumentT]:
        """import loose documents into a portfolio, (Statements)."""
        documents = DocSet(documents)
        rejected = set()

        ops = []
        for issuer_id in documents.issuers():
            policy = ImportPolicy(
                await self.facade.archive.vault.load_portfolio(
                    issuer_id, PGroup.VERIFIER_REVOKED
                )
            )
            for document in documents.get_issuer(issuer_id):
                if not Util.is_typing(document, StatementT):
                    raise TypeError("Document must be subtype of Statement")
                if policy.issued_document(document):
                    ops.append(
                        self.facade.archive.vault.save(
                            DOCUMENT_PATH[document.type].format(
                                dir="/portfolios/{0}".format(document.owner),
                                file=document.id,
                            ),
                            document,
                        )
                    )
                else:
                    rejected.add(document)

        result = await asyncio.gather(*ops, return_exceptions=True)
        return rejected, result

    async def list(
        self, query: str = "*"
    ) -> List[Tuple[bytes, Exception]]:
        """List all portfolio entities."""
        doclist = await self.facade.archive.vault.search(
            path="/portfolios/{0}.ent".format(query), limit=100
        )
        result = Glue.doc_validate_report(doclist, EntityT)
        return result