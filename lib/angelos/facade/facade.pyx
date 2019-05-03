# cython: language_level=3
"""Module docstring."""
import os
import logging
import asyncio

from ..utils import Util
from ..const import Const

from ..document.entities import Person, Ministry, Church, PrivateKeys, Keys
from ..document.domain import Domain, Node
from ..archive.vault import Vault
from ..archive.helper import Glue
from ..policy.accept import ImportEntityPolicy, ImportUpdatePolicy

from ..operation.setup import (
    SetupPersonOperation, SetupMinistryOperation, SetupChurchOperation)


class Facade:
    """
    Facade baseclass.

    The Facade is the gatekeeper of the integrity. The facade garantuees the
    integrity of the entity and its domain. It is here where all policies are
    enforced and where security is checked. No document can be imported without
    being verified.
    """

    def __init__(self, home_dir, secret, vault=None):
        """
        Initialize the facade class.

        Opens the Vault with the secret key and loads the core documents.
        """
        self._path = home_dir
        self._secret = secret

        if isinstance(vault, Vault):
            self._vault = vault
        else:
            self._vault = Vault(
                os.path.join(home_dir, Const.CNL_VAULT), secret)

    @classmethod
    async def setup(cls, home_dir, secret, role, entity_data=None, entity=None,
                    privkeys=None, keys=None, domain=None, node=None):
        """Create the existence of a new facade from scratch."""
        Util.is_type(home_dir, str)
        Util.is_type(secret, bytes)
        Util.is_type(role, int)

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

        if role not in [Const.A_ROLE_PRIMARY, Const.A_ROLE_BACKUP]:
            RuntimeError('Unsupported use of facade')

        if entity_data:
            entity, privkeys, keys, domain, node = cls.PREFS[1].create_new(
                entity_data)

        entity, privkeys, keys, domain, node = cls.PREFS[1].import_ext(
            entity, privkeys, keys, domain, node)

        vault = Vault.setup(
            os.path.join(home_dir, Const.CNL_VAULT),
            entity, privkeys, keys, domain, node, secret=secret,
            _type=cls.INFO[0], role=role, use=Const.A_USE_VAULT)

        facade = cls(home_dir, secret, vault)
        await facade.__post_init()
        return facade

    @staticmethod
    async def open(home_dir, secret):
        """
        Load an existing facade.

        The Vault is opened before the creation of the Facade so the right sort
        can be instanciated.
        """
        vault = Vault(os.path.join(home_dir, Const.CNL_VAULT), secret)
        _type = vault._archive.stats().type

        if _type == Const.A_TYPE_PERSON_CLIENT:
            facade = PersonClientFacade(home_dir, secret, vault)
        elif _type == Const.A_TYPE_PERSON_SERVER:
            facade = PersonServerFacade(home_dir, secret, vault)
        elif _type == Const.A_TYPE_MINISTRY_CLIENT:
            facade = MinistryClientFacade(home_dir, secret, vault)
        elif _type == Const.A_TYPE_MINISTRY_SERVER:
            facade = MinistryServerFacade(home_dir, secret, vault)
        elif _type == Const.A_TYPE_CHURCH_CLIENT:
            facade = ChurchClientFacade(home_dir, secret, vault)
        elif _type == Const.A_TYPE_CHURCH_SERVER:
            facade = ChurchServerFacade(home_dir, secret, vault)
        else:
            raise RuntimeError('Unkown archive type: %s' % str(_type))

        await facade.__post_init()
        return facade

    async def __post_init(self):
        identity = await self._vault.load_identity()

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

    @property
    def entity(self):
        """Entity core document getter."""
        return self.__entity

    @property
    def keys(self):
        """Public keys core document getter."""
        return self.__keys

    @property
    def domain(self):
        """Domain core document getter."""
        return self.__domain

    @property
    def node(self):
        """Node core document getter."""
        return self.__node

    def import_entity(self, entity, keys):
        """
        Import an entity.

        Import a foreign entity and its public keys. Enforces
        ImportEntityPolicy.
        """
        valid = True
        dir = None
        policy = ImportEntityPolicy()
        if isinstance(entity, Person):
            valid = policy.person(entity, keys)
            dir = '/entities/persons'
        elif isinstance(entity, Ministry):
            valid = policy.ministry(entity, keys)
            dir = '/entities/ministries'
        elif isinstance(entity, Church):
            valid = policy.church(entity, keys)
            dir = '/entities/churches'
        else:
            logging.warning('Invalid entity type')
            raise TypeError('Invalid entity type')

        if not valid:
            logging.info('Entity or Keys are invalid')
            raise RuntimeError('Entity or Keys are invalid')
        else:
            Glue.run_async(
                self._vault.save(os.path.join(
                    dir, str(entity.id) + '.pickle'), entity),
                self._vault.save(os.path.join(
                    '/keys', str(keys.id) + '.pickle'), keys)
            )

            return True

    def update_keys(self, newkeys):
        """
        Import new public keys.

        Imports new public keys for already imported foreign entity. Enforces
        ImportUpdatePolicy.
        """
        entity = self.find_entity(newkeys.issuer)
        keylist = self.find_keys(newkeys.issuer)

        valid = False
        for keys in keylist:
            policy = ImportUpdatePolicy(entity, keys)
            if policy.keys(newkeys):
                valid = True
                break

        if valid:
            result = asyncio.get_event_loop().run_until_complete(
                self._vault.save(os.path.join(
                    '/keys', str(newkeys.id) + '.pickle'), newkeys))
            if isinstance(result, Exception):
                raise result
            logging.info('New keys imported')
            return True
        else:
            logging.error('New keys invalid')
            return False

    def update_entity(self, entity):
        """
        Import updated entity document.

        Imports an updated version for already imported foreign entity.
        Enforces ImportUpdatePolicy.
        """
        old_ent = self.find_entity(entity.id)
        keylist = self.find_keys(entity.id)

        dir = None
        if isinstance(entity, Person):
            dir = '/entities/persons'
        elif isinstance(entity, Ministry):
            dir = '/entities/ministries'
        elif isinstance(entity, Church):
            dir = '/entities/churches'
        else:
            logging.warning('Invalid entity type')
            raise TypeError('Invalid entity type')

        valid = False
        for keys in keylist:
            policy = ImportUpdatePolicy(old_ent, keys)
            if policy.entity(entity):
                valid = True
                break

        if valid:
            result = asyncio.get_event_loop().run_until_complete(
                self._vault.update(os.path.join(
                    dir, str(entity.id) + '.pickle'), entity))
            if isinstance(result, Exception):
                raise result
            logging.info('updated entity imported')
            return True
        else:
            logging.error('Updated entity invalid')
            return False

    def find_keys(self, issuer, expiry_check=True):
        """
        Load public keys.

        Loads public keys belonging to issuing entity.
        """
        doclist = Glue.run_async(self._vault.issuer(issuer, '/keys/', 10))
        return Glue.doc_check(doclist, Keys, expiry_check)

    def find_entity(self, issuer, expiry_check=True):
        """
        Load foreign entity docuemnt.

        Loads the entity document based on the issuers ID.
        """
        doclist = Glue.run_async(self._vault.issuer(issuer, '/entities/*', 1))
        entitylist = Glue.doc_check(
            doclist, (Person, Ministry, Church), expiry_check)

        return entitylist[0] if len(entitylist) else None


class PersonFacadeMixin:
    """Mixin for a Person Facade."""

    PREFS = (Person, SetupPersonOperation)


class MinistryFacadeMixin:
    """Mixin for a Ministry Facade."""

    PREFS = (Ministry, SetupMinistryOperation)


class ChurchFacadeMixin:
    """Mixin for a Church Facade."""

    PREFS = (Church, SetupChurchOperation)


class ServerFacadeMixin:
    """Mixin for a Server Facade."""


class ClientFacadeMixin:
    """Mixin for a Church Facade."""


class PersonClientFacade(Facade, ClientFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity in a client."""

    INFO = (Const.A_TYPE_PERSON_CLIENT, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class PersonServerFacade(Facade, ServerFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity as a server."""

    INFO = (Const.A_TYPE_PERSON_SERVER, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class MinistryClientFacade(Facade, ClientFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity in a client."""

    INFO = (Const.A_TYPE_MINISTRY_CLIENT, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class MinistryServerFacade(Facade, ServerFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity as a server."""

    INFO = (Const.A_TYPE_MINISTRY_SERVER, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class ChurchClientFacade(Facade, ClientFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity in a client."""

    INFO = (Const.A_TYPE_CHURCH_CLIENT, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)


class ChurchServerFacade(Facade, ServerFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity as a server."""

    INFO = (Const.A_TYPE_CHURCH_SERVER, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)
