# cython: language_level=3
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""Mixin for enforcing portfolio policy's before importing."""
import asyncio
import uuid
from pathlib import PurePosixPath
from typing import Tuple, Set, Union

from angelos.common.policy import evaluate, Report
from angelos.document.document import Document
from angelos.document.statements import Verified, Trusted, Revoked
from angelos.document.utils import Helper as DocumentHelper
from angelos.lib.error import Error
from angelos.portfolio.collection import Portfolio, PrivatePortfolio
from angelos.portfolio.domain.accept import AcceptDomain, AcceptUpdatedDomain
from angelos.portfolio.domain.validate import ValidateDomain
from angelos.portfolio.entity.accept import AcceptEntity, AcceptUpdatedEntity, AcceptNewKeys, AcceptPrivateKeys
from angelos.portfolio.entity.validate import ValidatePrivateKeys
from angelos.portfolio.network.accept import AcceptUpdatedNetwork, AcceptNetwork
from angelos.portfolio.network.validate import ValidateNetwork
from angelos.portfolio.node.accept import AcceptNode, AcceptUpdatedNode
from angelos.portfolio.node.validate import ValidateNode
from angelos.portfolio.profile.accept import AcceptProfile, AcceptUpdatedProfile
from angelos.portfolio.profile.validate import ValidateProfile
from angelos.portfolio.statement.accept import AcceptTrustedStatement, AcceptVerifiedStatement, AcceptRevokedStatement
from angelos.portfolio.statement.validate import ValidateTrustedStatement, ValidateVerifiedStatement, \
    ValidateRevokedStatement
from angelos.portfolio.utils import Groups, Fields, Helper as PortfolioHelper


class PortfolioMixin:
    """Mixin that lets a storage deal with a portfolio repository."""

    PATH_PORTFOLIOS = (PurePosixPath("/portfolios/"),)

    def portfolio_path(self, eid: uuid.UUID) -> PurePosixPath:
        """Generate portfolio path for a particular entity id."""
        return self.PATH_PORTFOLIOS[0].joinpath(str(eid))

    async def portfolio_files(self, path: PurePosixPath, owner: uuid.UUID = None):
        """Glob a list of all files in a portfolio."""
        return await self.archive.glob(name=str(path.joinpath("*")), owner=owner)

    async def portfolio_exists_not(self, path: PurePosixPath, eid: uuid.UUID):
        """Check that portfolio exists."""
        is_dir = await self.archive.isdir(path)
        if not is_dir:
            raise Error.exception(Error.PORTFOLIO_EXISTS_NOT, {"portfolio": eid})

    async def write_file(self, filename: PurePosixPath, doc: Document):
        """Write a document to the current archive."""
        is_file = await self.archive.isfile(filename)
        if is_file:
           return self.archive.save(filename=filename, data=DocumentHelper.serialize(doc))
        else:
            created, updated, owner = DocumentHelper.meta(doc)
            return self.archive.mkfile(
                filename=filename, data=DocumentHelper.serialize(doc), id=doc.id,
                created=created, modified=updated, owner=owner
            )

    async def remove_file(self, doc: Revoked):
        """Remove a revoked statement to the current archive."""
        files = await self.archive.glob(id=doc.issuance)
        for path in files:
           await self.archive.remove(filename=path)

    async def accept_portfolio(self, portfolio: Portfolio) -> Report:
        """Accept a new portfolio of documents into the vault.

        All policies are being applied, if any document is invalid a policy breach will be raised.
        The owner documents are excluded.
        """
        with evaluate() as report:
            AcceptEntity().validate(portfolio)

            if portfolio.profile:
                ValidateProfile().validate(portfolio, portfolio.profile)

            if portfolio.network:
                ValidateNetwork.validate(portfolio, portfolio.network)

            for trusted in portfolio.trusted_issuer:
                ValidateTrustedStatement().validate(portfolio, trusted)

            for verified in portfolio.verified_issuer:
                ValidateVerifiedStatement().validate(portfolio, verified)

            for revoked in portfolio.revoked_issuer:
                ValidateRevokedStatement().validate(portfolio, revoked)

            if isinstance(portfolio, PrivatePortfolio):
                ValidatePrivateKeys().validate(portfolio, portfolio.privkeys)

                ValidateDomain().validate(portfolio, portfolio.domain)

                for node in portfolio.nodes:
                    ValidateNode().validate(portfolio, node)

        if report:
            await self.new_portfolio(PrivatePortfolio(portfolio.issuer()) if isinstance(
                portfolio, PrivatePortfolio) else Portfolio(portfolio.issuer()))

        return report

    async def update_portfolio(self, portfolio: Portfolio) -> Report:
        """Update an existing portfolio in storage with documents.

        This method applies policies while doing document comparison.
        """
        original = await self.load_portfolio(portfolio.entity.id, Groups.ALL)

        with evaluate() as report:
            if portfolio.entity > original.entity:
                AcceptUpdatedEntity().validate(original, portfolio.entity)

            for key in portfolio.keys:
                if key not in original:
                    AcceptNewKeys().validate(original, key)

            if portfolio.profile:
                if portfolio.profile not in original:
                    AcceptProfile().validate(original, portfolio.profile)
                elif portfolio.profile > original.profile:
                    AcceptUpdatedProfile().validate(original, portfolio.profile)

            if portfolio.network:
                if portfolio.network not in original:
                    AcceptNetwork().validate(original, portfolio.network)
                elif portfolio.network > original.network:
                    AcceptUpdatedNetwork().validate(original, portfolio.network)

            for trusted in portfolio.trusted_issuer:
                if trusted not in original:
                    AcceptTrustedStatement().validate(original, trusted)

            for verified in portfolio.verified_issuer:
                if verified not in original:
                    AcceptVerifiedStatement().validate(original, verified)

            for revoked in portfolio.revoked_issuer:
                if revoked not in original:
                    AcceptRevokedStatement().validate(original, revoked)

            if isinstance(portfolio, PrivatePortfolio) and isinstance(original, PrivatePortfolio):
                if portfolio.privkeys not in original:
                    AcceptPrivateKeys().validate(original, portfolio.privkeys)

                if portfolio.domain:
                    if portfolio.domain not in original:
                        AcceptDomain().validate(original, portfolio.domain)
                    elif portfolio.domain > original.domain:
                        AcceptUpdatedDomain().validate(original, portfolio.domain)

                for node in portfolio.nodes:
                    if node not in original:
                        AcceptNode().validate(original, node)
                    elif node > original.get_id(node.id):
                        AcceptUpdatedNode().validate(original, node)

        if report:
            await self.save_portfolio(PrivatePortfolio(original.issuer()) if isinstance(
                original, PrivatePortfolio) else Portfolio(original.issuer()))

        return report

    async def docs_to_portfolio(self, documents: Set[Union[Revoked, Trusted, Verified]]):
        """Import a bunch of statements to several portfolios.

        This method applies policies including revoked.
        """
        statements = set()
        revokes = set()
        for issuer_id in set([doc.issuer for doc in documents]):
            portfolio = await self.load_portfolio(issuer_id, Groups.VERIFIER_REVOKED)
            for issuance in [doc for doc in documents if doc.issuer == issuer_id]:
                with evaluate() as report:
                    if isinstance(issuance, Revoked):
                        ValidateRevokedStatement().validate(portfolio, issuance)
                        statements.add(issuance)
                        revokes.add(issuance)
                    elif isinstance(issuance, Trusted):
                        ValidateTrustedStatement().validate(portfolio, issuance)
                        statements.add(issuance)
                    elif isinstance(issuance, Verified):
                        ValidateVerifiedStatement().validate(portfolio, issuance)
                        statements.add(issuance)

        await self.gather(*[await self.write_file(self.PATH_PORTFOLIOS[0].joinpath(
            str(issuance.issuer), str(issuance.id) + DocumentHelper.extension(
                issuance.type)), issuance) for issuance in statements])

        await self.gather(*[await self.remove_file(issuance) for issuance in revokes])

    async def list_portfolios(self) -> Set[Tuple[str, uuid.UUID]]:
        """Load a list of all portfolios.

        Returns (List[Tuple[str, uuid.UUID]]):
            List of tuples with portfolio path and ID.

        """
        result = await self.search(
            str(self.PATH_PORTFOLIOS[0]) + "*/*.ent",
            link=True,
            limit=None,
            deleted=False,
            fields=lambda name, entry: (name,) # entry.owner)
        )
        return set(result.keys())

    async def new_portfolio(self, portfolio: Portfolio) -> bool:
        """Write new portfolio to archive."""
        dirname = self.portfolio_path(portfolio.entity.id)

        is_dir = await self.archive.isdir(dirname)
        if is_dir:
            raise Error.exception(Error.PORTFOLIO_ALREADY_EXISTS, {
                "portfolio": portfolio.entity.id})

        await self.archive.mkdir(dirname)

        files = list()
        for doc in portfolio.documents():
            files.append((dirname.joinpath(str(doc.id) + DocumentHelper.extension(doc.type)), doc))

        ops = list()
        for doc in files:
            created, updated, owner = DocumentHelper.meta(doc[1])
            ops.append(self.archive.mkfile(
                filename=doc[0], data=DocumentHelper.serialize(doc[1]), id=doc[1].id,
                created=created, modified=updated, owner=owner,
            ))

        return await self.gather(*ops)

    async def save_portfolio(self, portfolio: Portfolio) -> bool:
        """Save a changed portfolio.

        This method expects policies to be applied."""
        dirname = self.portfolio_path(portfolio.entity.id)
        await self.portfolio_exists_not(dirname, portfolio.entity.id)

        self.gather(*[await self.write_file(
            dirname.joinpath(str(doc.id) + DocumentHelper.extension(doc.type)), doc) for doc in portfolio.issuer()])

        return True

    async def load_portfolio(self, eid: uuid.UUID, config: Tuple[str]) -> Portfolio:
        """Load portfolio based on uuid."""
        dirname = self.portfolio_path(eid)
        await self.portfolio_exists_not(dirname, eid)

        files = await self.portfolio_files(dirname, owner=eid)
        pattern = PortfolioHelper.suffixes(config)
        files = {filename for filename in files if filename.suffix in pattern}
        docs_data = await asyncio.gather(*[self.archive.load(filename) for filename in files])
        documents = {DocumentHelper.deserialize(data) for data in docs_data}
        portfolio = PrivatePortfolio(documents) if Fields.PRIVKEYS in config else Portfolio(documents)

        return portfolio

    async def reload_portfolio(self, portfolio: Portfolio, config: Tuple[str]) -> bool:
        """Synchronize portfolio from storage."""
        eid = portfolio.entity.id
        dirname = self.portfolio_path(eid)
        await self.portfolio_exists_not(dirname, eid)

        files = await self.portfolio_files(dirname, owner=eid)
        pattern = PortfolioHelper.suffixes(config)
        doc_ids = {str(doc.id) for doc in portfolio.documents()}
        files = {filename for filename in files if filename.suffix in pattern and filename.stem not in doc_ids}
        docs_data = await asyncio.gather(*[self.archive.load(filename) for filename in files])
        documents = {DocumentHelper.deserialize(data) for data in docs_data}
        portfolio.__init__(portfolio.documents() | documents)

        return True

    async def delete_portfolio(self, eid: uuid.UUID) -> bool:
        """Delete an existing portfolio, except the owner."""
        if eid == self.facade.data.portfolio.entity.id:
            raise Error.exception(Error.PORTFOLIO_ILLEGAL_DELETE, {"portfolio": eid})

        dirname = self.portfolio_path(eid)
        await self.portfolio_exists_not(dirname, eid)

        files = await self.portfolio_files(dirname)
        await self.gather(*[self.archive.remove(filename=filename, mode=3) for filename in files])

        return True
