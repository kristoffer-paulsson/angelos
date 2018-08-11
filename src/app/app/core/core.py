from ..task import TaskGroup
from .console import Console


class Core(TaskGroup):
    NAME = 'Core'

    def task_list(self):
        return {
            Console.NAME: lambda: Console(
                Console.NAME, self._sig, self._ioc, self._ioc.service('cmd'))
        }
