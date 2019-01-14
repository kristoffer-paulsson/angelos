import collections
import pickle
import uuid
import base64
import datetime
import types
import platform
import yaml
import libnacl.dual
import libnacl.sign
import libnacl.encode
import libnacl.utils
import plyer

from ..utils import Util
from ..error import ArchiveInvalidFile
from ..document.issuance import IssueMixin
from ..document.entity import Person, Keys
from ..document.document import Document
from ..document.network import Network, Node
from .facade import BaseFacade
from .archive import Entity as EntityArchive


class PersonFacade(BaseFacade):
    def __init__(self, path, secret):
        self.__configured = False
        self.__path = path

        self.__entity = None

        self.__facade = None
        self.__keys = None
        self.__secret = None

        if secret:
            box = libnacl.secret.SecretBox(
                libnacl.encode.hex_decode(
                    plyer.keystore.get_key('Λόγῳ', 'conceal')))
            self.__secret = box.decrypt(base64.b64decode(secret))

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
        Util.is_type(address, (self.Address, type(None)))
        self.__facade.address = address

    @property
    def email(self):
        return self.__facade.email

    @email.setter
    def email(self, email):
        Util.is_type(email, (str, type(None)))
        self.__facade.email = email

    @property
    def mobile(self):
        return self.__facade.mobile

    @mobile.setter
    def mobile(self, mobile):
        Util.is_type(mobile, (str, type(None)))
        self.__facade.mobile = mobile

    @property
    def phone(self):
        return self.__facade.phone

    @phone.setter
    def phone(self, phone):
        Util.is_type(phone, (str, type(None)))
        self.__facade.phone = phone

    class Social(collections.namedtuple('Social', [
        'token',
        'media',
    ])):
        __slots__ = ()

    @property
    def social(self):
        return self.__facade.social

    def add_social(self, media):
        Util.is_type(media, (self.Social))
        self.__facade.social[media.media.lower()] = media

    def del_social(self, media):
        try:
            del self.__facade.social[media.media.lower()]
        except KeyError:
            pass

    class Contacts(collections.namedtuple('Address', [
        'favorites',
        'friends',
        'family',
        'blocked',
        'all',
    ], defaults=([], [], [], [], []))):
        __slots__ = ()

    @property
    def picture(self):
        return self.__facade.picture

    @picture.setter
    def picture(self, picture):
        Util.is_type(picture, (bytearray, type(None)))
        self.__facade.picture = picture

    class Facade(types.SimpleNamespace):
        pass

    def initialize(self):
        """Initializes the Facade with the entity data from the database"""
        self.__entity = EntityArchive(self.__path, self.__secret)
        data = self.__load_identity()
        self.__configure(data)

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

        # Createing and signing the network document
        network = Network()
        network.owner = entity.id
        network = self.__issue(entity.id, network)

        # Creating and signing the node document
        node = Node()
        node.owner = entity.id
        node.network = network.id
        node.role = 'client'
        node.device = platform.platform()
        node.serial = plyer.uniqueid.id
        node = self.__issue(entity.id, node)

        # Signing the owners identity
        entity = self.__issue(entity.id, entity)

        # Setting up the concealed archives.
        box = libnacl.secret.SecretBox()
        skey = str(box.hex_sk(), 'utf_8')
        plyer.keystore.set_key('Λόγῳ', 'conceal', skey)

        self.__secret = libnacl.secret.SecretBox().sk
        with open(self.__path + '/default.yml', 'w') as config:
            config.write(yaml.dump({
                'configured': True, 'key': base64.b64encode(
                    box.encrypt(self.__secret))},
                default_flow_style=False, allow_unicode=True,
                explicit_start=True, explicit_end=True))
        self.__entity = EntityArchive.setup(
            self.__path, self.__secret, entity, network)

        # Importing the new identity
        self.import_new_person(entity, keys)
        self.set_network(network, keys)
        self.import_new_node(node, network, keys)

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

    def __configure(self, data):
        Util.is_type(data, dict)

        try:
            address = self.Address(**data['address'])
        except (KeyError, TypeError):
            address = None

        try:
            email = data['email']
        except (KeyError, TypeError):
            email = None

        try:
            mobile = data['mobile']
        except (KeyError, TypeError):
            mobile = None

        try:
            phone = data['phone']
        except (KeyError, TypeError):
            phone = None

        try:
            social = {}
            for media in data['social']:
                social[data['social'][media]['media'].lower()] = self.Social(
                    data['social'][media]['token'],
                    data['social'][media]['media'])
        except (KeyError, TypeError):
            social = {}

        try:
            contacts = self.Contacts(**data['contacts'])
        except (KeyError):
            contacts = self.Contacts()

        try:
            picture = data['picture']
        except (KeyError, TypeError):
            picture = None

        self.__facade = self.Facade(
            id=str(uuid.UUID(data['id'])),
            entity=self.Entity(**data['entity']),
            address=address,
            email=email,
            mobile=mobile,
            phone=phone,
            social=social,
            contacts=contacts,
            picture=picture)

        self.__keys = libnacl.dual.DualSecret(
            libnacl.encode.hex_decode(data['keys']['secret']),
            libnacl.encode.hex_decode(data['keys']['seed']))

        self.__configured = True

    def __load_identity(self):
        return self.__entity.read('/identity.pickle')

    def __save_identity(self):
        if bool(self.__facade.address):
            address = self.__facade.address._asdict()
        else:
            address = None

        if bool(self.__facade.social):
            social = {}
            for media in self.__facade.social:
                social[media] = self.__facade.social[media]._asdict()
        else:
            social = {}

        data = {
            'id': str(uuid.UUID(self.__facade.id)),
            'entity': self.__facade.entity._asdict(),
            'address': address,
            'email': self.__facade.email,
            'mobile': self.__facade.mobile,
            'phone': self.__facade.phone,
            'social': social,
            'contacts': self.__facade.contacts._asdict(),
            'picture':  self.__facade.picture,
            'keys': {
                'secret': self.__keys.hex_sk().decode('utf-8'),
                'seed': self.__keys.hex_seed().decode('utf-8'),
            }
        }

        pckl = pickle.dumps(data, pickle.DEFAULT_PROTOCOL)
        try:
            self.__entity.archive.info('/identity.pickle')
            self.__entity.archive.save('/identity.pickle', data=pckl)
        except ArchiveInvalidFile as e:
            self.__entity.archive.mkfile(
                '/identity.pickle', data=pckl,
                owner=uuid.UUID(self.__facade.id))


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
        self.__entity.create(
            '/keys/'+str(keys.id)+'.pickle', keys)

        # Importing the owners identity
        self.__entity.create(
            '/entities/persons/'+str(entity.id)+'.pickle', entity)

    def set_network(self, network, keys):
        Util.is_type(network, Network)

        # Evaluate the network expiery date
        today = datetime.date.today()
        if not network.expires > today:
            raise Exception()

        # Validate the network document
        if not network.validate():
            raise Exception()

        # Make sure that the key is issued by the network owner
        if not network.owner == keys.issuer:
            raise Exception()

        # Make sure that the key is issued by the key issuer
        if not network.issuer == keys.issuer:
            raise Exception()

        # Verify the signed network
        if not self.__verify(network, keys):
            raise Exception()

        # Importing the identitys public keys
        self.__entity.create(
            '/settings/network.pickle', network)

    def import_new_node(self, node, network, keys):
        Util.is_type(node, Node)
        Util.is_type(network, Network)
        Util.is_type(keys, Keys)

        today = datetime.date.today()

        # Evaluate the node expiery date
        if not node.expires > today:
            raise Exception()

        # Validate the node document
        if not node.validate():
            raise Exception()

        # Make sure that the nodes owner is the keys issuer
        if not node.owner == keys.issuer:
            raise Exception()

        # Make sure that the node is issued by the key issuer
        if not node.issuer == keys.issuer:
            raise Exception()

        # Make sure that the network is issued by the keys owner
        if not network.owner == keys.issuer:
            raise Exception()

        # Make sure that the issuer is issued by the key issuer
        if not network.issuer == keys.issuer:
            raise Exception()

        # Make sure that the node belong to the network
        if not node.network == network.id:
            raise Exception()

        # Verify the entity-signed key
        if not self.__verify(node, keys):
            raise Exception()

        # Importing the identitys public keys
        self.__entity.create(
            '/settings/nodes/'+str(node.id)+'.pickle', node)

    def find_person(self, issuer):
        res = self.__entity.search('/entities/persons', uuid.UUID(issuer))
        output = ''
        for doc in res:
            output += yaml.dump(
                Person(doc, False).export_yaml(),
                default_flow_style=False, allow_unicode=True,
                explicit_start=True, explicit_end=True)
        return output

    def find_keys(self, issuer):
        res = self.__entity.search('/keys', uuid.UUID(issuer))
        output = ''
        for doc in res:
            output += yaml.dump(
                Keys(doc, False).export_yaml(),
                default_flow_style=False, allow_unicode=True,
                explicit_start=True, explicit_end=True)
        return output

    def export_yaml(self, data={}):
        return yaml.dump(data, default_flow_style=False, allow_unicode=True,
                        explicit_start=True, explicit_end=True)

    def _finalize(self):
        print('Run finalize')
        if self.__entity:
            self.__entity.archive.close()

    class PolicyValidator:
        pass
