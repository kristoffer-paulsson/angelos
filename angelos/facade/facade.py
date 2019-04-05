import os
import base64
import plyer

import libnacl

from ..utils import Util

from ..document.entities import Person
from ..policy.entity import PersonGeneratePolicy
from ..policy.node import DomainPolicy, NodePolicy
from ..archive.vault import Vault


class Facade:
    def __init__(self, home_dir, secret):
        if secret:
            box = libnacl.secret.SecretBox(
                libnacl.encode.hex_decode(
                    plyer.keystore.get_key('Λόγῳ', 'conceal')))
            self.__secret = box.decrypt(base64.b64decode(secret))

    @staticmethod
    def setup(home_dir, entity_data=None):
        Util.is_type(home_dir, str)
        Util.is_type(entity_data, dict)

        ent_gen = PersonGeneratePolicy()
        ent_gen.generate(**entity_data)

        dom_gen = DomainPolicy(ent_gen.entity, ent_gen.private, ent_gen.keys)
        dom_gen.generate()

        nod_gen = NodePolicy(ent_gen.entity, ent_gen.private, ent_gen.keys)
        nod_gen.current(dom_gen.domain)

        vault = Vault.setup(
            os.path.join(home_dir, 'vault.ar7.cnl'), ent_gen.entity,
            ent_gen.private, ent_gen.keys, dom_gen.domain, nod_gen.node)

        vault.close()

        return Facade(home_dir, ent_gen.private.secret)


class PersonFacade(Facade):
    FACADE = (Person, PersonGeneratePolicy)
