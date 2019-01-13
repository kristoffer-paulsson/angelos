# import io
# import threading

# from .archive import Archive
# from .concean import ConcealIO


class BaseFacade:
    DEFAULT = 'default.ar7.cnl'

    # def __init__(self, path, secret, mode='w'):
    #    self.__thread_lock = threading.Lock()
    #    self.__default = Archive(ConcealIO(
    #        path + '/' + BaseFacade.DEFAULT, secret, mode))
