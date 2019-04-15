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
    def __init__(self):
        self._quit = False

    def call(self, callback, params, priority=1024):
        pass

    def run(self):
        pass

    def quit(self):
        self._quit = True

    class Task:
        def __init__(self, prio, callback, params):
            self.prio = prio
            self.callable = callback
            self.params = params
            self.result = None

        def __eq__(self, other):
            return self.prio == other.prio

        def __lt__(self, other):
            return self.prio < other.prio


class NullProxy(Proxy):
    def call(self, callback, priority=1024, timeout=10, **kwargs):
        return callback(**kwargs)


class ThreadProxy(Proxy):
    def __init__(self, size=0):
        Proxy.__init__(self)
        self.__queue = threading.PriorityQueue(size)

    def call(self, callback, priority=1024, timeout=10, **kwargs):
        task = Proxy.Task(priority, callback, kwargs)
        self.__queue.put(task)
        return task.result

    def run(self):
        while not (self._quit and self.__queue.empty()):
            task = self.__queue.get()
            logging.debug('Proxy prepare: %s; %s' % (task.prio, ', '.join(
                ": ".join(_) for _ in task.params.items())))
            result = task.callable(**task.params)
            logging.info('Proxy execution: "%s"' % str(task.callable.__name__))
            task.result = result if result else None
            self.__queue.task_done()


class AsyncProxy(Proxy):
    def __init__(self, size=0):
        Proxy.__init__(self)
        self.__queue = asyncio.PriorityQueue(size)
        self.task = asyncio.ensure_future(self.run())

    async def call(self, callback, priority=1024, timeout=10, **kwargs):
        try:
            task = Proxy.Task(priority, callback, kwargs)
            await asyncio.wait_for(self.__queue.put(task), timeout)
            return task.result
        except asyncio.TimeoutError as e:
            logging.exception(e)
            return None

    async def run(self):
        while not (self._quit and self.__queue.empty()):
            await self.__executor(await self.__queue.get())
            self.__queue.task_done()

    async def __executor(self, task):
        logging.debug('Proxy prepare: %s; %s' % (task.prio, ', '.join(
            ": ".join(_) for _ in task.params.items())))
        result = task.callable(**task.params)
        logging.info('Proxy execution: "%s"' % str(task.callable.__name__))
        task.result = result if result else None
