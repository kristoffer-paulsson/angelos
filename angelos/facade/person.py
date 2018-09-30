import collections
import uuid
import base64
import datetime
import types
import yaml
import libnacl.dual
import libnacl.sign
import libnacl.encode
from playhouse.shortcuts import model_to_dict

from ..utils import Util
from ..db.person import PersonDatabase
from ..document.issuance import IssueMixin
from ..document.entity import Person, Keys
from ..document.document import Document


class PersonFacade:
    def __init__(self, db, path):
        Util.is_type(db, PersonDatabase)
        self.__configured = False
        self.__path = path

        self.__facade = None
        self.__keys = None

    class Entity(collections.namedtuple('Entity', [
        'given_name',
        'names',
        'family_name',
        'born',
        'gender',
        'type'
    ])):
        __slots__ = ()

    @property
    def entity(self):
        return self.__facade.entity

    @property
    def id(self):
        return self.__facade.id

    class Address(collections.namedtuple('Address', [
        'street',
        'number',
        'address2',
        'zip',
        'city',
        'state',
        'country'
    ])):
        __slots__ = ()

    @property
    def address(self):
        return self.__facade.address

    @address.setter
    def address(self, address):
        Util.is_type(address, self.Address)
        self.__facade.address = address

    class Facade(types.SimpleNamespace):
        pass

    def initialize(self):
        """Initializes the Facade with the entity data from the database"""
        record = self.__load_identity()
        self.__configure(record.data)

    def save(self):
        self.__save_identity()

    def create(self, entity):
        Util.is_type(entity, Person)

        # Creating new set of key-pairs
        self.__keys = libnacl.dual.DualSecret()

        # Creating and signing the identitys public keys
        keys = Keys()
        keys.public = self.__keys.hex_pk().decode('utf-8')
        keys.verify = self.__keys.hex_vk().decode('utf-8')
        keys = self.__issue(entity.id, keys)

        # Signing the owners identity
        entity = self.__issue(entity.id, entity)

        # Importing the new identity
        self.import_new_person(entity, keys)

        # Configuring the facade and saving settings
        data = entity.export_str()
        self.__configure({
            'id': str(entity.id),
            'entity': {
                'given_name': data['given_name'],
                'names': data['names'],
                'family_name': data['family_name'],
                'born': data['born'],
                'gender': data['gender'],
                'type': 'person'
            },
            'keys': {
                'secret': self.__keys.hex_sk().decode('utf-8'),
                'seed': self.__keys.hex_seed().decode('utf-8'),
            }
        })
        self.__save_identity()

        with open(self.__path + '/default.yml', 'w') as config:
            config.write(yaml.dump(
                {'configured': True}, default_flow_style=False,
                allow_unicode=True, explicit_start=True, explicit_end=True))

    def __configure(self, data):
        Util.is_type(data, dict)

        try:
            address = self.Address(**data['address'])
        except (KeyError, TypeError):
            address = None

        self.__facade = self.Facade(
            id=str(uuid.UUID(data['id'])),
            entity=self.Entity(**data['entity']),
            address=address)

        self.__keys = libnacl.dual.DualSecret(
            libnacl.encode.hex_decode(data['keys']['secret']),
            libnacl.encode.hex_decode(data['keys']['seed']))

        self.__configured = True

    def __load_identity(self):
        return PersonDatabase.Identity.get(pk='i')

    def __save_identity(self):
        if bool(self.__facade.address):
            address = self.__facade.address._asdict()
        else:
            address = None

        data = {
            'id': str(self.__facade.id),
            'entity': self.__facade.entity._asdict(),
            'address': address,
            'keys': {
                'secret': self.__keys.hex_sk().decode('utf-8'),
                'seed': self.__keys.hex_seed().decode('utf-8'),
            }
        }
        try:
            (PersonDatabase.Identity().get(
                pk='i').update(data=data)).execute()
        except PersonDatabase.Identity.DoesNotExist:
            PersonDatabase.Identity().create(
                id=uuid.UUID(self.__facade.id), data=data)

    def __issue(self, id, document):
        Util.is_type(id, uuid.UUID)
        Util.is_type(document, Document)
        Util.is_type(document, IssueMixin)

        document.sign(
            id, self.__keys.signature(
                bytes(str(id) + document.data_msg(), 'utf-8')))
        return document

    def __verify(self, document, keys):
        """
        Verification might be able to have several modes. Documents might have
        one or several signatures. This causes a situation where different
        policys on how to apply verification is available.
        """
        Util.is_type(document, Document)
        Util.is_type(keys, Keys)

        if document.issuer != keys.issuer:
            raise Exception()

        verificator = libnacl.sign.Verifier(keys.verify)

        if isinstance(document.signature, list):
            verified = False
            for signature in document.signature:
                signature = bytes(
                    base64.standard_b64decode(signature))
                try:
                    verificator.verify(signature +
                                       bytes(document.issuer, 'utf-8') +
                                       bytes(document.data_msg(), 'utf-8'))
                    verified = True
                except ValueError:
                    pass
            return verified
        else:
            try:
                verificator.verify(
                    bytes(base64.standard_b64decode(document.signature)) +
                    bytes(str(document.issuer), 'utf-8') +
                    bytes(document.data_msg(), 'utf-8'))
            except ValueError:
                return False
            return True

    def import_new_person(self, entity, keys):
        Util.is_type(entity, Person)
        Util.is_type(keys, Keys)

        today = datetime.date.today()

        # Evaluate the entity expiery date
        if not entity.expires > today:
            raise Exception()

        # Evaluate the keys expiery date
        if not keys.expires > today:
            raise Exception()

        # Validate the entity document
        if not entity.validate():
            raise Exception()

        # Validate the keys document
        if not keys.validate():
            raise Exception()

        # Make sure that the key is issued by the entity
        if not entity.id == keys.issuer:
            raise Exception()

        # Make sure the entity is self-signed
        if not entity.id == entity.issuer:
            raise Exception()

        # Verify the entity-signed key
        if not self.__verify(keys, keys):
            raise Exception()

        # Verify the self-signed entity
        if not self.__verify(entity, keys):
            raise Exception()

        # Importing the identitys public keys
        PersonDatabase.Keys().create(
            **PersonDatabase.prepare(keys.export()))

        # Importing the owners identity
        PersonDatabase.Person().create(
            **PersonDatabase.prepare(entity.export()))

    def find_person(self, issuer):
        res = (PersonDatabase.Person.select().where(
            PersonDatabase.Person.issuer == issuer)).execute()
        output = ''
        for doc in res:
            output += yaml.dump(Person(
                model_to_dict(doc), False).export(), default_flow_style=False,
                      allow_unicode=True, explicit_start=True,
                      explicit_end=True)
        return output

    def find_keys(self, issuer):
        res = (PersonDatabase.Keys.select().where(
            PersonDatabase.Keys.issuer == issuer)).execute()
        output = ''
        for doc in res:
            output += yaml.dump(Keys(
                model_to_dict(doc), False).export(), default_flow_style=False,
                      allow_unicode=True, explicit_start=True,
                      explicit_end=True)
        return output

    def export_yaml(self, data={}):
        print(yaml.dump(data, default_flow_style=False, allow_unicode=True,
                        explicit_start=True, explicit_end=True))

    class PolicyValidator:
        pass
