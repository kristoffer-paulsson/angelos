# cython: language_level=3
"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring."""
import datetime
import threading
import asyncio
import logging
import uuid
import pickle

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

    @staticmethod
    def doc_check(datalist, _type, expiry_check=True):
        # validity = datetime.date.today() - datetime.timedelta(year=3)
        validity = datetime.date.today()
        doclist = []

        for data in datalist:
            doc = pickle.loads(data)
            if isinstance(doc, _type):
                # doc.validate()
                if expiry_check and doc.expires > validity:
                    doclist.append(doc)
                elif not expiry_check:
                    doclist.append(doc)

        return doclist

    @staticmethod
    def doc_validate(datalist, _type):
        doclist = []

        for data in datalist:
            try:
                doc = None
                doc = pickle.loads(data)
                Util.is_type(doc, _type)
                doc.validate()
                doclist.append(doc)
            except Exception as e:
                pass

        return doclist

    @staticmethod
    def doc_validate_report(datalist, _type):
        doclist = []

        for data in datalist:
            try:
                doc = None
                doc = pickle.loads(data)
                Util.is_type(doc, _type)
                doc.validate()
                doclist.append((doc, None))
            except Exception as e:
                doclist.append((doc if doc else data, str(e)))

        return doclist

    @staticmethod
    def run_async(*aws, raise_exc=True):
        loop = asyncio.get_event_loop()
        gathering = asyncio.gather(
            *aws, loop=loop, return_exceptions=True)
        loop.run_until_complete(gathering)

        result_list = gathering.result()
        exc = None
        for result in result_list:
            if isinstance(result, Exception):
                exc = result if not exc else exc
                logging.error('Operation failed: %s' % result)
        if exc:
            raise exc
        if len(result_list) > 1:
            return result_list
        else:
            return result_list[0]


class Globber:
    @staticmethod
    def full(archive, filename='*', cmp_uuid=False):
        Util.is_type(archive, Archive7)

        with archive.lock:
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

        return files

    @staticmethod
    def owner(archive, owner, path='/'):
        Util.is_type(archive, Archive7)
        Util.is_type(path, str)
        Util.is_type(owner, (str, uuid.UUID))

        with archive.lock:
            sq = Archive7.Query(path).owner(owner).type(b'f')
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

        return files

    @staticmethod
    def path(archive, path='*'):
        Util.is_type(archive, Archive7)

        with archive.lock:
            sq = Archive7.Query(path).type(b'f')
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

        return files


class Proxy:
    def __init__(self):
        self._quit = False

    def call(self, callback, priority=1024, timeout=10, **kwargs):
        if not callable(callback):
            raise TypeError('Not a callable. Type: %s' % type(callback))
        if self._quit:
            raise RuntimeError('Proxy has quit, no more calls')

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
        if not callable(callback):
            raise TypeError('Not a callable. Type: %s' % type(callback))
        if self._quit:
            raise RuntimeError('Proxy has quit, no more calls')
        try:
            result = callback(**kwargs)
            logging.info('Proxy execution: "%s"' % str(callback.__name__))
            return result
        except Exception as e:
            logging.error(
                'Proxy execution failed: "%s"' % str(callback.__name__))
            return e


class ThreadProxy(Proxy):
    def __init__(self, size=0):
        Proxy.__init__(self)
        self.__queue = threading.PriorityQueue(size)

    def call(self, callback, priority=1024, timeout=10, **kwargs):
        if not callable(callback):
            raise TypeError('Not a callable. Type: %s' % type(callback))
        if self._quit:
            raise RuntimeError('Proxy has quit, no more calls')

        task = Proxy.Task(priority, callback, kwargs)
        self.__queue.put(task)
        return task.result

    def run(self):
        while not (self._quit and self.__queue.empty()):
            task = self.__queue.get()
            try:
                result = task.callable(**task.params)
                logging.info(
                    'Proxy execution: "%s"' % str(task.callable.__name__))
                task.result = result  # if result else None
            except Exception as e:
                logging.error(
                    'Proxy execution failed: "%s"' % str(
                        task.callable.__name__))
                task.result = e
            self.__queue.task_done()


class AsyncProxy(Proxy):
    def __init__(self, size=0):
        Proxy.__init__(self)
        self.__queue = asyncio.PriorityQueue(size)
        self.task = asyncio.ensure_future(self.run())

    async def call(self, callback, priority=1024, timeout=10, **kwargs):
        if not callable(callback):
            raise TypeError('Not a callable. Type: %s' % type(callback))
        if self._quit:
            raise RuntimeError('Proxy has quit, no more calls')

        try:
            task = Proxy.Task(priority, callback, kwargs)
            await asyncio.wait_for(self.__queue.put(task), timeout)
            return task.result
        except asyncio.TimeoutError as e:
            logging.exception(e)
            return None

    async def run(self):
        while True:
            task = await self.__queue.get()
            if task is None:
                break
            await self.__executor(task)
            self.__queue.task_done()

    def quit(self):
        Proxy.quit(self)
        self.__queue.put_nowait(None)

    async def __executor(self, task):
        try:
            result = task.callable(**task.params)
            logging.info('Proxy execution: "%s"' % str(task.callable.__name__))
            task.result = result  # if result else None
        except Exception as e:
            logging.error(
                'Proxy execution failed: "%s"' % str(task.callable.__name__))
            task.result = e
