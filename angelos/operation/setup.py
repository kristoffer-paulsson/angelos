"""Module docstring."""
import logging

from ..utils import Util

from ..document.entities import Person, Ministry, Church, PrivateKeys, Keys
from ..document.domain import Domain, Node
from .operation import Operation
from ..policy.crypto import Crypto
from ..policy.entity import (
    PersonGeneratePolicy, MinistryGeneratePolicy, ChurchGeneratePolicy)
from ..policy.domain import DomainPolicy, NodePolicy


class BaseSetupOperation(Operation):
    @classmethod
    def create_new(cls, entity_data):
        Util.is_type(entity_data, dict)

        logging.info('Creating new entity of type: %s' % type(cls.ENTITY[0]))

        ent_gen = cls.ENTITY[1]()
        ent_gen.generate(**entity_data)

        dom_gen = DomainPolicy(ent_gen.entity, ent_gen.privkeys, ent_gen.keys)
        dom_gen.generate()

        nod_gen = NodePolicy(ent_gen.entity, ent_gen.privkeys, ent_gen.keys)
        nod_gen.current(dom_gen.domain)

        return (
            ent_gen.entity, ent_gen.privkeys, ent_gen.keys,
            dom_gen.domain, nod_gen.node
        )

    @classmethod
    def import_ext(cls, entity, privkeys, keys, domain, node=None):
        Util.is_type(entity, cls.ENTITY[0])
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(keys, Keys)
        Util.is_type(domain, Domain)
        Util.is_type(node, (Node, type(None)))

        logging.info(
            'Importing entity of type: %s' % type(cls.ENTITY[0]))

        if not node:
            nod_gen = NodePolicy(entity, privkeys, keys)
            nod_gen.current(domain)
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
    ENTITY = (Person, PersonGeneratePolicy)


class SetupMinistryOperation(BaseSetupOperation):
    ENTITY = (Ministry, MinistryGeneratePolicy)


class SetupChurchOperation(BaseSetupOperation):
    ENTITY = (Church, ChurchGeneratePolicy)
