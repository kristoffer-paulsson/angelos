import datetime
import threading
import asyncio
import logging
import uuid

from ..utils import Util
from .archive7 import Archive7


class Glue:
    @staticmethod
    def doc_save(document):
        try:
            owner = document.owner
        except AttributeError:
            owner = document.issuer

        try:
            updated = datetime.datetime.combine(
                document.updated, datetime.datetime.min.time())
        except (AttributeError, TypeError):
            updated = None

        created = datetime.datetime.combine(
            document.created, datetime.datetime.min.time())

        return created, updated, owner


class Globber:
    @staticmethod
    def full(archive, filename='*', cmp_uuid=False):
        Util.is_type(archive, Archive7)

        archive._lock()

        sq = Archive7.Query(pattern=filename)
        sq.type(b'f')
        idxs = archive.ioc.entries.search(sq)
        ids = archive.ioc.hierarchy.ids

        files = {}
        for i in idxs:
            idx, entry = i
            if entry.parent.int == 0:
                name = '/'+str(entry.name, 'utf-8')
            else:
                name = ids[entry.parent]+'/'+str(entry.name, 'utf-8')
            if cmp_uuid:
                files[entry.id] = (name, entry.deleted, entry.modified)
            else:
                files[name] = (entry.id, entry.deleted, entry.modified)

        archive._unlock()
        return files

    @staticmethod
    def owner(archive, owner, path='/'):
        Util.is_type(archive, Archive7)
        Util.is_type(path, str)
        Util.is_type(owner, (str, uuid.UUID))

        archive._lock()

        pid = archive.ioc.operations.get_pid(path)
        sq = Archive7.Query().owner(owner).parent(pid).type(b'f')
        idxs = archive.ioc.entries.search(sq)
        ids = archive.ioc.hierarchy.ids

        files = []
        for i in idxs:
            idx, entry = i
            if entry.parent.int == 0:
                name = '/'+str(entry.name, 'utf-8')
            else:
                name = ids[entry.parent]+'/'+str(entry.name, 'utf-8')
            files.append((name, entry.id, entry.created))

        archive._unlock()
        return files


class Proxy:
    def __init__(self, event, size=0):
        pass

    def call(self, callback, params, priority=1024):
        pass

    def run(self):
        pass

    class Task:
        def __init__(self, callback, params):
            self.callable = callback
            self.params = params
            self.result = None


class NullProxy:
    def call(self, callback, priority=1024, timeout=10, **kwargs):
        return callback(**kwargs)


class ThreadProxy:
    def __init__(self, event, size=0):
        Util.is_type(event, threading._Event)
        self.__quit = event
        self.__queue = threading.PriorityQueue(size)

    def call(self, callback, priority=1024, timeout=10, **kwargs):
        task = Proxy.Task(params=kwargs)
        self.__queue.put((priority, task))
        return task.result

    def run(self):
        while not self.__quit.is_set() or not self.__queue.empty():
            task = self.__queue.get()
            result = task.callable(**task.params)
            task.result = result if result else None
            self.__queue.task_done()


class AsyncProxy:
    def __init__(self, event, size=0):
        Util.is_type(event, asyncio._Event)
        self.__quit = event
        self.__queue = asyncio.PriorityQueue(size)

    async def call(self, callback, priority=1024, timeout=10, **kwargs):
        try:
            task = Proxy.Task(params=kwargs)
            await asyncio.wait_for(self.__queue.put((priority, task)), timeout)
            return task.result
        except asyncio.TimeoutError as e:
            logging.exception(e)
            return None

    async def run(self):
        while not self.__quit.is_set() or not self.__queue.empty():
            await self.__executor(await self.__queue.get())
            self.__queue.task_done()

    async def __executor(self, task):
        result = task.callable(**task.params)
        task.result = result if result else None
