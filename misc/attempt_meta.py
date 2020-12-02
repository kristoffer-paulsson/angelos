class KlassMeta(type):
    """Example meta class."""

    def __new__(mcs, name: str, bases: tuple, namespace: dict):
        pass

    def __init__(cls, **kwargs):
        pass

    def __call__(cls, *args, **kwargs):
        pass

    def __prepare__(metacls, name, bases=None, **kwargs):
        pass


class Klass(metaclass=KlassMeta):
    """Example base class."""

    def __init_subclass__(cls):
        pass

    def __new__(cls, *args, **kwargs):
        pass

    def __init__(self, *args, **kwargs):
        pass


class MyKlass(Klass):
    """Example utility class."""
    pass