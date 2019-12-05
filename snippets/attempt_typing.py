from typing import Union, _GenericAlias


class A:
    pass


class B:
    pass


class C:
    pass


CA = Union[A, B]


def funny(bla: Union[CA, C]):
    print(type(CA))
    print(CA.__args__, isinstance(bla, CA.__args__))


funny(A())
funny(B())
funny(C())

print(type(CA) is _GenericAlias)