"""Module docstring."""


class Runtime:
    def __init__(self, config):
        self.__home = config['home']
        self.__mode = config['mode']
        self.__type = config['type']
        self.__role = config['role']
        self.__platform = config['platform']

    @property
    def home(self):
        return self.__home

    @property
    def mode(self):
        return self.__mode

    @property
    def type(self):
        return self.__type

    @property
    def role(self):
        return self.__role

    @property
    def platform(self):
        return self.__platform
