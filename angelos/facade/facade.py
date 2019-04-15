import os
import logging

from ..utils import Util

from ..document.entities import Person, Ministry, Church, PrivateKeys, Keys
from ..document.domain import Domain, Node
from ..archive.vault import Vault

from ..operation.setup import (
    SetupPersonOperation, SetupMinistryOperation, SetupChurchOperation)


class Facade:
    def __init__(self, home_dir, secret):
        pass


class BaseFacade:
    def __init__(self, home_dir, secret, vault=None):
        self._path = home_dir
        self._secret = secret

        if isinstance(vault, Vault):
            self._vault = vault
        else:
            self._vault = Vault(
                os.path.join(home_dir, 'vault.ar7.cnl'), secret)

        identity = self._vault.load_identity()

        Util.is_type(identity[0], self.PREFS[0])
        Util.is_type(identity[1], PrivateKeys)
        Util.is_type(identity[2], Keys)
        Util.is_type(identity[3], Domain)
        Util.is_type(identity[4], Node)

        self.__entity = identity[0]
        self.__privkeys = identity[1]
        self.__keys = identity[2]
        self.__domain = identity[3]
        self.__node = identity[4]

    @classmethod
    def setup(cls, home_dir, secret, entity_data=None, entity=None,
              privkeys=None, keys=None, domain=None, node=None):
        Util.is_type(home_dir, str)
        Util.is_type(secret, bytes)

        if entity_data:
            Util.is_type(entity_data, dict)
            Util.is_type(entity, type(None))
            Util.is_type(privkeys, type(None))
            Util.is_type(keys, type(None))
            Util.is_type(domain, type(None))
            Util.is_type(node, type(None))
        else:
            Util.is_type(entity_data, type(None))
            Util.is_type(entity, cls.PREFS[0])
            Util.is_type(privkeys, PrivateKeys)
            Util.is_type(keys, Keys)
            Util.is_type(domain, Domain)
            Util.is_type(node, (Node, type(None)))

        logging.info('Setting up facade of type: %s' % type(cls))

        if not os.path.isdir(home_dir):
            RuntimeError('Home directory doesn\'t exist')

        if entity_data:
            entity, privkeys, keys, domain, node = cls.PREFS[1].create_new(
                entity_data)

        entity, privkeys, keys, domain, node = cls.PREFS[1].import_ext(
            entity, privkeys, keys, domain, node)

        vault = Vault.setup(
            os.path.join(home_dir, 'vault.ar7.cnl'),
            entity, privkeys, keys, domain, node, secret=secret)

        return cls(home_dir, secret, vault)

    @property
    def entity(self):
        return self.__entity

    @property
    def keys(self):
        return self.__keys

    @property
    def domain(self):
        return self.__domain

    @property
    def node(self):
        return self.__node

    def import_entity(self, entity, keys, update=False):
        pass

    def import_keys(self, keys):
        pass

    def find_keys(self, issuer):
        pass

    def find_entity(self, issuer):
        pass


class PersonFacadeMixin:
    PREFS = (Person, SetupPersonOperation)


class MinistryFacadeMixin:
    PREFS = (Ministry, SetupMinistryOperation)


class ChurchFacadeMixin:
    PREFS = (Church, SetupChurchOperation)


class ServerFacadeMixin:
    pass


class ClientFacadeMixin:
    pass


class PersonClientFacade(BaseFacade, ClientFacadeMixin, PersonFacadeMixin):
    def __init__(self, home_dir, secret, vault=None):
        BaseFacade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class PersonServerFacade(BaseFacade, ServerFacadeMixin, PersonFacadeMixin):
    def __init__(self, home_dir, secret, vault=None):
        BaseFacade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class MinistryClientFacade(BaseFacade, ClientFacadeMixin, MinistryFacadeMixin):
    def __init__(self, home_dir, secret, vault=None):
        BaseFacade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class MinistryServerFacade(BaseFacade, ServerFacadeMixin, MinistryFacadeMixin):
    def __init__(self, home_dir, secret, vault=None):
        BaseFacade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class ChurchClientFacade(BaseFacade, ClientFacadeMixin, ChurchFacadeMixin):
    def __init__(self, home_dir, secret, vault=None):
        BaseFacade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)


class ChurchServerFacade(BaseFacade, ServerFacadeMixin, ChurchFacadeMixin):
    def __init__(self, home_dir, secret, vault=None):
        BaseFacade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)
