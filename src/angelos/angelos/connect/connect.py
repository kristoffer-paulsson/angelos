from .admin import AdminServer
from app import TaskGroup


class Connect(TaskGroup):
    NAME = 'Connect'

    def task_list(self):
        return {
            AdminServer.NAME: lambda: AdminServer(
                AdminServer.NAME, self._sig)
        }
