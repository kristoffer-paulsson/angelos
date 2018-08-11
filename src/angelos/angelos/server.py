import time
from app import Application


class Server(Application):
    """@todo"""
    def _initialize(self):
        """
        Things to be done prior to main process loop execution. This method
        should be overriden.
        """
        self._tasks = self._ioc.service('tasks')
        self._tasks.level_exec(0)
        time.sleep(2)
        self._tasks.level_exec(1)
        time.sleep(2)
        self._tasks.level_exec(2)

    def _finalize(self):
        """
        Things to be done after main process loop execution. This method can be
        overriden. Don't forget to stop the TaskManager.
        """
        self._tasks.stop()
