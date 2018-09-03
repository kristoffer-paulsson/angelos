"""Docstring"""
import threading
import asyncio
import collections
import logging
import traceback
from .utils import Util
from .error import Error
from .ioc import Container


class Worker:
    """Docstring"""
    def __init__(self, ioc):
        """Docstring"""
        Util.is_type(ioc, Container)

        self.ioc = ioc

        self._halt = threading.Event()
        self._halt.clear()

        self._thread = None
        self._loop = None

    def _setup(self):
        """Docstring"""
        self._loop = asyncio.new_event_loop()
        self._loop.set_exception_handler(self._exception_handler)
        self._loop.set_debug(True)

    def _teardown(self):
        """Docstring"""
        self._loop.close()

    def _exception_handler(self, loop, context):
        """Docstring"""
        loop.default_exception_handler(context)
        exc = context.get('exception')
        if isinstance(exc, Exception):
            ftr_exc = context.get('future').exception()
            ftr_trb = 'Traceback (task exception):\n{0}{1} {2}'.format(
                ''.join(traceback.format_tb(ftr_exc.__traceback__)),
                str(type(ftr_exc)), str(ftr_exc))

            logging.critical(
                '%s\n%s\n%s',
                'Unhandled exception in worker',
                context.get('message'),
                ftr_trb)
        else:
            logging.critical('An unknown exception in worker')
        loop.stop()
        self._panic()

    def _initialize(self):
        """Docstring"""
        pass

    def _finalize(self):
        """Docstring"""
        pass

    def _panic(self):
        """Docstring"""
        pass

    def run(self):
        """Docstring"""
        logging.info('Starting worker %s', id(self))
        self._setup()
        self._initialize()
        try:
            self._loop.run_forever()
            tasks = asyncio.Task.all_tasks(self._loop)
            for t in [t for t in tasks if not (t.done() or t.cancelled())]:
                self._loop.run_until_complete(t)
        except KeyboardInterrupt as e:
            logging.exception(e)
            self._panic()
        except Exception as e:
            logging.exception(e)
            self._loop.run_until_complete(self._loop.shutdown_asyncgens())
            self._panic()
        self._finalize()
        self._teardown()
        logging.info('Exiting worker %s', id(self))

    def start(self):
        """Docstring"""
        self._thread = threading.Thread(target=self.run)
        self._thread.start()

    def stop(self):
        """Docstring"""
        self._halt.set()
        self._loop.stop()


class Workers:
    """Docstring"""
    WorkerInstance = collections.namedtuple(
        'WorkerInstance', ['worker', 'name', 'group'])

    def __init__(self):
        self.__lock = threading.Lock()
        self.__workers = {}

    def add(self, name, group, worker):
        """Docstring"""
        Util.is_type(name, str)
        Util.is_type(group, str)
        Util.is_type(worker, Worker)

        with self.__lock:

            if name in self.__workers:
                raise Util.exception(Error.WORKER_ALREADY_REGISTERED)

            self.__workers[name] = self.WorkerInstance(
                worker=worker, name=name, group=group)

    def stop(self, group='all'):
        """Docstring"""
        with self.__lock:

            total = len(self.__workers)
            stopped = 0

            for wi in self.__workers:
                if group == 'all':
                    self.__workers[wi].worker.stop()
                    stopped += 1
                elif self.__workers[wi].group == group:
                    self.__workers[wi].worker.stop()
                    stopped += 1

            return (stopped, total)

    def name(self, worker):
        """Docstring"""
        with self.__lock:

            for wi in self.__workers:
                if worker is self.__workers[wi].worker:
                    return (self.__workers[wi].name, self.__workers[wi].group)

            raise Util.exception(Error.WORKER_NOT_REGISTERED)
