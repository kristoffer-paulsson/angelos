import uuid
import yaml
import libnacl.dual
from .utils import Util
from .document.document import Document
from .document.entity import Person, Keys
from .db.person import PersonDatabase


class Setup:
    def __init__(self, db):
        Util.is_type(db, PersonDatabase)
        self.__db = db
        self.__keys = libnacl.dual.DualSecret()

    def sign_document(self, id, document):
        Util.is_type(id, uuid.UUID)
        Util.is_type(document, Document)

        document.sign(
            id, self.__keys.signature(str(id) + document.data_msg()))
        return document

    def export_yaml(self, data={}):
        print(yaml.dump(data, default_flow_style=False, allow_unicode=True,
                        explicit_start=True, explicit_end=True))

    def make_home(self, entity, path):
        Util.is_type(entity, Person)

        entity = self.sign_document(entity.id, entity)
        PersonDatabase.Person().create(
            **PersonDatabase.prepare(entity.export()))

        keys = Keys()
        keys.public = self.__keys.hex_pk().decode('utf-8')
        keys.verify = self.__keys.hex_vk().decode('utf-8')
        keys = self.sign_document(entity.id, keys)
        PersonDatabase.Keys().create(
            **PersonDatabase.prepare(keys.export()))

        PersonDatabase.Identity().create(id=entity.id, data={
            'id': str(entity.id),
            'entity': {
                'given_name': entity.given_name,
                'names': entity.names,
                'family_name': entity.family_name,
                'born': str(entity.born),
                'gender': entity.gender,
                'type': 'person'
            },
            'keys': {
                'secret': self.__keys.hex_sk().decode('utf-8'),
                'seed': self.__keys.hex_seed().decode('utf-8'),
            }
        })

        with open(path + '/default.yml', 'w') as config:
            config.write(yaml.dump(
                {'configured': True}, default_flow_style=False,
                allow_unicode=True, explicit_start=True, explicit_end=True))
