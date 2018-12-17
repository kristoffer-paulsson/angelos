import io
import threading
import tarfile
from .concean import ConcealIO


class BaseFacade:
    def __init__(self, path, secret, mode='w'):
        self.tar = tarfile.open(
            fileobj=ConcealIO(path, secret, mode), mode=mode + ':bz2')
        self.__thread_lock = threading.Lock()

    def create(self, name, data):
        with self.__thread_lock:
            buffer = io.BytesIO(data)
            buffer.seek(0)

            info = tarfile.TarInfo(name=name)
            info.size = len(buffer.getbuffer())
            self.tar.addfile(tarinfo=info, fileobj=buffer)

    def read(self, name):
        with self.__thread_lock:
            return self.tar.extractfile(name).read()
        # return self.tar.extractfile(name).fileobj

    def update(self, name, data):
        pass

    def delete(self, name):
        pass

    def close(self):
        self.tar.close()

    def get_block(self, blk):
        return self.fileobj._load(blk)
