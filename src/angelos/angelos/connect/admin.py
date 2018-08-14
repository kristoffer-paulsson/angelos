from app import Task


class AdminServer(Task):
    NAME = 'AdminServer'

    def __init__(self, name, sig):
        Task.__init__(self, name, sig)

        self.__socket = None
        self.__server = None

    def _initialize(self):
        pass

    def _finilize(self):
        pass

    def work(self):
        pass
