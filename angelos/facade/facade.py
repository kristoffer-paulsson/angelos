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
    def __init__(self, home_dir, secret):
        self._path = home_dir
        self._secret = secret

        self._vault = Vault(
            os.path.join(home_dir, 'vault.ar7.cnl'), secret)

        identity = self._vault.load_identity()
        self._entity = identity[0]
        self._private = identity[1]
        self._keys = identity[2]
        self._domain = identity[3]
        self._node = identity[4]

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

        vault.close()

        return cls(home_dir, secret)


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
    def __init__(self, home_dir, secret):
        BaseFacade.__init__(self, home_dir, secret)
        ClientFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class PersonServerFacade(BaseFacade, ServerFacadeMixin, PersonFacadeMixin):
    def __init__(self, home_dir, secret):
        BaseFacade.__init__(self, home_dir, secret)
        ServerFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class MinistryClientFacade(BaseFacade, ClientFacadeMixin, MinistryFacadeMixin):
    def __init__(self, home_dir, secret):
        BaseFacade.__init__(self, home_dir, secret)
        ClientFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class MinistryServerFacade(BaseFacade, ServerFacadeMixin, MinistryFacadeMixin):
    def __init__(self, home_dir, secret):
        BaseFacade.__init__(self, home_dir, secret)
        ServerFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class ChurchClientFacade(BaseFacade, ClientFacadeMixin, ChurchFacadeMixin):
    def __init__(self, home_dir, secret):
        BaseFacade.__init__(self, home_dir, secret)
        ClientFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)


class ChurchServerFacade(BaseFacade, ServerFacadeMixin, ChurchFacadeMixin):
    def __init__(self, home_dir, secret):
        BaseFacade.__init__(self, home_dir, secret)
        ServerFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)
