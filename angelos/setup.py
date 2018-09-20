import yaml
import libnacl.dual
from .utils import Util
from .document.entity import Person, Keys


class Setup:
    def __init__(self, type, entity):
        Util.is_type(entity, Person)

        self.__keys = libnacl.dual.DualSecret()

        self.__entity = self.sign_entity(entity)
        self.__public = self.make_keys(self.__keys, entity)

        self.export_yaml(self.__entity.export())
        self.export_yaml(self.__public.export())

    def sign_entity(self, entity):
        Util.is_type(entity, Person)

        entity.sign(
            entity.id, self.__keys.signature(
                str(entity.id) + entity.data_msg()))

        return entity

    def make_keys(self, nacl_dual, entity):
        Util.is_type(nacl_dual, libnacl.dual.DualSecret)
        Util.is_type(entity, Person)

        keys = Keys()
        keys.public = nacl_dual.hex_pk().decode('utf-8')
        keys.verify = nacl_dual.hex_vk().decode('utf-8')
        keys.sign(
            entity.id, nacl_dual.signature(
                str(entity.id) + keys.data_msg()))

        return keys

    def make_home(self):
        pass

    def export_yaml(self, data={}):
        print(yaml.dump(data,
                        default_flow_style=False,
                        allow_unicode=True,
                        explicit_start=True,
                        explicit_end=True))
