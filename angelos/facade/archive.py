import io
import threading
import tarfile

from .conceal import ConcealIO


class BaseArchive:
    COMPRESSION = ':bz2'

    def __init__(self, path, secret, mode='w'):
        self.__path = path
        self.__secret = secret

        self.__lock = threading.Lock()
        self.__tar = tarfile.open(
            fileobj=ConcealIO(path, secret, mode), mode=mode[0] + BaseArchive.COMPRESSION)

    def create(self, name, data):
        with self.__thread_lock:
            buffer = io.BytesIO(data)
            buffer.seek(0)

            info = tarfile.TarInfo(name=name)
            info.size = len(buffer.getbuffer())
            self.tar.addfile(tarinfo=info, fileobj=buffer)

    def read(self, name):
        with self.__thread_lock:
            data = self.tar.extractfile(name).read()
        return data

    def update(self, name, data):
        pass

    def delete(self, name):
        pass

    def close(self):
        self.tar.close()
