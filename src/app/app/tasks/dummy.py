from random import choice
from time import sleep
from ..task import Task, TaskGroup


class Dummy(Task):
    NAME = 'Dummy'

    def __init__(self, sig):
        Task.__init__(self, self.NAME, sig)

    def work(self):
        c = choice([0, 1])
        if c is 0:
            self._idle(1)
        elif c is 1:
            sleep(1)


class Dummy1(Dummy):
    NAME = 'Dummy_1'


class Dummy2(Dummy):
    NAME = 'Dummy_2'


class Dummy3(Dummy):
    NAME = 'Dummy_3'


class Dummy4(Dummy):
    NAME = 'Dummy_4'


class Dummies(TaskGroup):
    NAME = 'Dummies'

    def task_list(self):
        return {
            Dummy1.NAME: lambda: Dummy1(self._sig),
            Dummy2.NAME: lambda: Dummy2(self._sig),
            Dummy3.NAME: lambda: Dummy3(self._sig),
            Dummy4.NAME: lambda: Dummy4(self._sig)
        }
