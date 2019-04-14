
from .archive7 import Archive7


class BaseArchive:
    def __init__(self, filename, secret, delete=Archive7.Delete.HARD):
        self._archive = Archive7.open(filename, secret, delete)
        self._closed = False
