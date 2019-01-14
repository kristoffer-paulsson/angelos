from ..util import Util
from .archive import Archive


class Check:
    def __init__(self, archive):
        Util.is_type(archive, Archive)
        self.__test = test

    def run(self):
        pass
