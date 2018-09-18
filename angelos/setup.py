import libnacl.dual


from .document.entity import EntityFactory


class Setup:
    def __init__(self, type, entity):
        self.__type = type
        self.__entity = entity
        doc = EntityFactory.person(**entity)
        keys = libnacl.dual.DualSecret()
        print(doc.yaml())
