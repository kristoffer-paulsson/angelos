"""Module docstring."""


class Runtime:
    def __init__(self, config):
        self.__root = config['root']
        self.__mode = config['mode']
        self.__type = config['type']
        self.__role = config['role']
        self.__platform = config['platform']

    def root(self):
        return self.__root

    def mode(self):
        return self.__mode

    def type(self):
        return self.__type

    def role(self):
        return self.__role

    def platform(self):
        return self.__platform
