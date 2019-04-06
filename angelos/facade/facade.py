import os

from ..utils import Util

from ..policy.entity import PersonGeneratePolicy
from ..policy.domain import DomainPolicy, NodePolicy
from ..archive.vault import Vault


class Facade:
    def __init__(self, home_dir, secret):
        self.__path = home_dir
        self.__secret = secret

        self.__vault = Vault(
            os.path.join(home_dir, 'vault.ar7.cnl'), secret)

        identity = self.__vault.load_identity()
        self.__entity = identity[0]
        self.__private = identity[1]
        self.__keys = identity[2]
        self.__domain = identity[3]
        self.__node = identity[4]

        print(identity[0])
        print(identity[1])
        print(identity[2])
        print(identity[3])
        print(identity[4])
        # if secret:
        #    box = libnacl.secret.SecretBox(
        #        libnacl.encode.hex_decode(
        #            plyer.keystore.get_key('Λόγῳ', 'conceal')))
        #    self.__secret = box.decrypt(base64.b64decode(secret))

    @staticmethod
    def setup(home_dir, entity_data=None, secret=None):
        Util.is_type(home_dir, str)
        Util.is_type(entity_data, dict)

        if not os.path.isdir(home_dir):
            RuntimeError('Home directory doesn\'t exist')

        ent_gen = PersonGeneratePolicy()
        ent_gen.generate(**entity_data)

        dom_gen = DomainPolicy(ent_gen.entity, ent_gen.private, ent_gen.keys)
        dom_gen.generate()

        nod_gen = NodePolicy(ent_gen.entity, ent_gen.private, ent_gen.keys)
        nod_gen.current(dom_gen.domain)

        vault = Vault.setup(
            os.path.join(home_dir, 'vault.ar7.cnl'), ent_gen.entity,
            ent_gen.private, ent_gen.keys, dom_gen.domain, nod_gen.node,
            secret=secret)

        vault.close()

        return Facade(home_dir, secret)


class BaseFacade:
    def __init__(self):
        self._vault = None


class PersonFacadeMixin:
    pass


class MinistryFacadeMixin:
    pass


class ChurchFacadeMixin:
    pass


class ServerFacadeMixin:
    pass


class ClientFacadeMixin:
    pass


class PersonClientFacade(BaseFacade, ClientFacadeMixin, PersonFacadeMixin):
    def __init__(self):
        BaseFacade.__init__(self)
        ClientFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class PersonServerFacade(BaseFacade, ServerFacadeMixin, PersonFacadeMixin):
    def __init__(self):
        BaseFacade.__init__(self)
        ServerFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class MinistryClientFacade(BaseFacade, ClientFacadeMixin, MinistryFacadeMixin):
    def __init__(self):
        BaseFacade.__init__(self)
        ClientFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class MinistryServerFacade(BaseFacade, ServerFacadeMixin, MinistryFacadeMixin):
    def __init__(self):
        BaseFacade.__init__(self)
        ServerFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class ChurchClientFacade(BaseFacade, ClientFacadeMixin, ChurchFacadeMixin):
    def __init__(self):
        BaseFacade.__init__(self)
        ClientFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)


class ChurchServerFacade(BaseFacade, ServerFacadeMixin, ChurchFacadeMixin):
    def __init__(self):
        BaseFacade.__init__(self)
        ServerFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)
