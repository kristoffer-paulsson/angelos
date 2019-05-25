# cython: language_level=3
"""Module docstring."""
import logging

from ..utils import Util

from ..document import (
    Person, Ministry, Church, PrivateKeys, Keys, Domain, Node)
from .operation import Operation
from .policy._types import (
    PersonData, MinistryData, ChurchData, PrivatePortfolioABC)
from ..policy.crypto import Crypto
from ..policy.entity import (
    PersonGeneratePolicy, MinistryGeneratePolicy, ChurchGeneratePolicy,
    PersonPolicy, MinistryPolicy, ChurchPolicy)
from ..policy.domain import DomainPolicy, NodePolicy


class BaseSetupOperation(Operation):
    """Baseclass for entity setup/import operations."""

    @staticmethod
    def _generate(
            portfolio: PrivatePortfolioABC,
            role: str='client', server: bool=False):
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

    @classmethod
    def import_ext(cls, entity, privkeys, keys, domain,
                   node=None, role='client', server=False):
        """Validate a set of documents related to an entity for import."""
        Util.is_type(entity, cls.ENTITY[0])
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(keys, Keys)
        Util.is_type(domain, Domain)
        Util.is_type(node, (Node, type(None)))

        logging.info(
            'Importing entity of type: %s' % type(cls.ENTITY[0]))

        if not node:
            nod_gen = NodePolicy(entity, privkeys, keys)
            nod_gen.current(domain, role=role, server=server)
            node = nod_gen.node

        valid = True
        if not node.domain == domain.id:
            logging.error('Node and Domain document mismatch')
            valid = False

        if not entity.validate():
            logging.error('Entity document invalid')
            valid = False

        if not keys.validate():
            logging.error('Keys document invalid')
            valid = False

        if not privkeys.validate():
            logging.error('Private keys document invalid')
            valid = False

        if not domain.validate():
            logging.error('Domain document invalid')
            valid = False

        if not node.validate():
            logging.error('Node document invalid')
            valid = False

        if not Crypto.verify(entity, entity, keys):
            logging.error('Entity document verification failed')
            valid = False

        if not Crypto.verify(keys, entity, keys):
            logging.error('Keys document verification failed')
            valid = False

        if not Crypto.verify(privkeys, entity, keys):
            logging.error('Private keys document verification failed')
            valid = False

        if not Crypto.verify(domain, entity, keys):
            logging.error('Domain document verification failed')
            valid = False

        if not Crypto.verify(node, entity, keys):
            logging.error('Node document verification failed')
            valid = False

        if not valid:
            raise RuntimeError('Importing external documents failed')

        return (entity, privkeys, keys, domain, node)


class SetupPersonOperation(BaseSetupOperation):
    """Person entity setup policy."""

    ENTITY = (Person, PersonGeneratePolicy)

    @classmethod
    def create(cls, data: PersonData, role: str='client', server: bool=False):
        portfolio = PersonPolicy.generate(data)
        BaseSetupOperation._generate(portfolio)
        return portfolio


class SetupMinistryOperation(BaseSetupOperation):
    """Ministry entity setup policy."""

    ENTITY = (Ministry, MinistryGeneratePolicy)

    @classmethod
    def create(
            cls, data: MinistryData, role: str='client', server: bool=False):
        portfolio = MinistryPolicy.generate(data)
        BaseSetupOperation._generate(portfolio)
        return portfolio


class SetupChurchOperation(BaseSetupOperation):
    """Church entity setup policy."""

    ENTITY = (Church, ChurchGeneratePolicy)

    @classmethod
    def create(cls, data: ChurchData, role: str='client', server: bool=False):
        portfolio = ChurchPolicy.generate(data)
        BaseSetupOperation._generate(portfolio)
        return portfolio
