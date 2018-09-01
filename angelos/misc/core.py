from ..const import Const
from ..task import TaskGroup
from .admin import AdminServer


class Core(TaskGroup):
    NAME = 'Core'

    def task_list(self):
        return {
            Const.W_ADMIN_NAME: lambda: AdminServer(
                name=AdminServer.NAME, sig=self._sig, ioc=self._ioc)
        }
