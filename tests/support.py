import os
import io


def filesize(file):
    if isinstance(file, io.IOBase):
        return os.fstat(file.fileno()).st_size
    else:
        return os.stat(file).st_size
