import libnacl.dual


class Setup:
    def __init__(self, type, entity):
        self.__type = type
        self.__entity = entity
        keys = libnacl.dual.DualSecret()
        entity.sign(entity.id, keys.signature(entity.data_msg()))
        print(entity.export())
