# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring."""
from .operation import Operation
from ..policy import (
    PersonData, MinistryData, ChurchData, PrivatePortfolio, Crypto,
    PersonPolicy, MinistryPolicy, ChurchPolicy, DomainPolicy, NodePolicy)


class BaseSetupOperation(Operation):
    """Baseclass for entity setup/import operations."""

    @staticmethod
    def _generate(
            portfolio: PrivatePortfolio,
            role: str='client', server: bool=False) -> bool:
        """
        Issue a new set of documents from entity data.

        The following documents will be issued:
        Entity, PrivateKeys, Keys, Domain and Node.
        """

        if not DomainPolicy.generate(portfolio):
            raise RuntimeError('Domain document not generated')

        if not NodePolicy.current(portfolio, role, server):
            raise RuntimeError('Node document not generated')

        return True

    @staticmethod
    def import_ext(
            portfolio: PrivatePortfolio,
            role: str='client', server: bool=False) -> bool:
        """Validate a set of documents related to an entity for import."""

        if not portfolio.nodes:
            NodePolicy.current(portfolio, role=role, server=server)

        valid = True
        for node in portfolio.nodes:
            if not node.domain == portfolio.domain.id:
                raise RuntimeError('Node and Domain document mismatch')
                valid = False

        if not portfolio.entity.validate():
            raise RuntimeError('Entity document invalid')
            valid = False

        for keys in portfolio.keys:
            if not keys.validate():
                raise RuntimeError('Keys document invalid')
                valid = False

        if not portfolio.privkeys.validate():
            raise RuntimeError('Private keys document invalid')
            valid = False

        if not portfolio.domain.validate():
            raise RuntimeError('Domain document invalid')
            valid = False

        for node in portfolio.nodes:
            if not node.validate():
                raise RuntimeError('Node document invalid')
                valid = False

        if not Crypto.verify(portfolio.entity, portfolio):
            raise RuntimeError('Entity document verification failed')
            valid = False

        for keys in portfolio.keys:
            if not Crypto.verify(keys, portfolio):
                raise RuntimeError('Keys document verification failed')
                valid = False

        if not Crypto.verify(portfolio.privkeys, portfolio):
            raise RuntimeError('Private keys document verification failed')
            valid = False

        if not Crypto.verify(portfolio.domain, portfolio):
            raise RuntimeError('Domain document verification failed')
            valid = False

        for node in portfolio.nodes:
            if not Crypto.verify(node, portfolio):
                raise RuntimeError('Node document verification failed')
                valid = False

        return valid


class SetupPersonOperation(BaseSetupOperation):
    """Person entity setup policy."""

    @classmethod
    def create(
            cls, data: PersonData, role: str='client',
            server: bool=False) -> PrivatePortfolio:
        portfolio = PersonPolicy.generate(data)
        BaseSetupOperation._generate(portfolio, role, server)
        return portfolio


class SetupMinistryOperation(BaseSetupOperation):
    """Ministry entity setup policy."""

    @classmethod
    def create(
            cls, data: MinistryData, role: str='client',
            server: bool=False) -> PrivatePortfolio:
        portfolio = MinistryPolicy.generate(data)
        BaseSetupOperation._generate(portfolio, role, server)
        return portfolio


class SetupChurchOperation(BaseSetupOperation):
    """Church entity setup policy."""

    @classmethod
    def create(
            cls, data: ChurchData, role: str='client',
            server: bool=False) -> PrivatePortfolio:
        portfolio = ChurchPolicy.generate(data)
        BaseSetupOperation._generate(portfolio, role, server)
        return portfolio
