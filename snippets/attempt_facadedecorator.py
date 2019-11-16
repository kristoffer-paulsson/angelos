import inspect
import pprint

# class facadeonly:
#    def __init__(self, decorated):
#        self.__decorated = decorated

#    def __call__(self, *args, **kwargs):
#        return self.__decorated(*args, **kwargs)


def facadeonly(decorator):
    stack2 = inspect.stack()
    owner_obj = stack2[0][0].f_locals['decorator'].__name__
    print(decorator.__self__)
    pprint.pprint(dir(owner_obj))

    def inner_func(calling_obj, *args, **kwargs):
        stack = inspect.stack()
        caller_obj = stack[1][0].f_locals["self"]
        print(caller_obj)
        # caller_obj is the caller of my_method
        return decorator(calling_obj, *args, **kwargs)
    return inner_func


class internal:
    def __init__(self, decoratee, owner="internal"):
        self.__decoratee = decoratee
        self.__owner = owner

    def __get__(self, instance, owner):
        self.__instance = instance
        return self.__call__

    def __call__(self, *args, **kwargs):
        stack = inspect.stack()
        caller_instance = stack[1][0].f_locals["self"]
        owner_instance = getattr(self.__instance, self.__owner, None)

        if caller_instance != owner_instance:
            raise RuntimeError("Illegal access to internal method %s.%s" % (
                type(self.__instance).__name__, self.__decoratee.__name__))

        return self.__decoratee(self.__instance, *args, **kwargs)


class Facade:
    pass


class FacadeFrozen:
    def __init__(self, facade):
        self.__facade = facade

    @property
    def facade(self):
        """Expose a readonly weakref of the facade.

        Returns
        -------
        Facade
            weak reference to the owning facade.

        """
        return self.__facade


class Proxy(FacadeFrozen):
    @internal
    def test(self):
        print("Hello, world")


class Caller:
    def __init__(self, proxy):
        self.__proxy = proxy

    def test(self):
        self.__proxy.test()


if "__main__" in __name__:
    facade = Facade()
    proxy = Proxy(facade)
    caller = Caller(proxy)
    print("Caller:", caller)
    print("Facade:", proxy.facade)
    caller.test()
