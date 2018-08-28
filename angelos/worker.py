import threading
import asyncio
import collections
from .utils import Util
from .error import Error
from .ioc import Container


class Worker:
    def __init__(self, ioc):
        Util.is_type(ioc, Container)

        self.ioc = ioc

        self._halt = threading.Event()
        self._halt.clear()

        self._thread = None
        self._loop = None

    def _setup(self):
        self._loop = asyncio.new_event_loop()
        self._loop.set_debug(True)

    def _teardown(self):
        self._loop.close()
        # self._thread.join()

    def _initialize(self):
        pass

    def _finalize(self):
        pass

    def run(self):
        self._setup()
        self._initialize()
        try:
            self._loop.run_forever()
            tasks = asyncio.Task.all_tasks(self._loop)
            for t in [t for t in tasks if not (t.done() or t.cancelled())]:
                self._loop.run_until_complete(t)
        except Exception as e:
            raise e
        finally:
            self._loop.run_until_complete(self._loop.shutdown_asyncgens())
        self._finalize()
        self._teardown()

    def start(self):
        self._thread = threading.Thread(target=self.run)
        self._thread.start()

    def stop(self):
        self._halt.set()
        self._loop.stop()


class Workers:
    WorkerInstance = collections.namedtuple(
        'WorkerInstance', ['worker', 'name', 'group'])

    def __init__(self):
        self.__lock = threading.Lock()
        self.__workers = {}

    def add(self, name, group, worker):
        Util.is_type(name, str)
        Util.is_type(group, str)
        Util.is_type(worker, Worker)

        with self.__lock:

            if name in self.__workers:
                Util.exception(Error.WORKER_ALREADY_REGISTERED)

            self.__workers[name] = self.WorkerInstance(
                worker=worker, name=name, group=group)

    def stop(self, group='all'):
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
        with self.__lock:

            for wi in self.__workers:
                if worker is self.__workers[wi].worker:
                    return (self.__workers[wi].name, self.__workers[wi].group)

            Util.exception(Error.WORKER_NOT_REGISTERED)
