import sys
import os
import atexit
import time
import threading
import asyncio
from signal import SIGTERM
from ..events import Event
from ..worker import Worker
from .admin import AdminServer


class ServerEvent(Event):
    MESSAGE_QUIT = 1

    def __init__(self, sender, message, data={}):
        Event.__init__(self, sender, Application.NAME, message, data)


class Application(Worker):
    NAME = 'Supervisor'

    def __init__(self, ioc):
        Worker.__init__(self, ioc)
        self.ioc.workers.add(Application.NAME, 'Core', self)

    def start(self):
        self.run()

    def _initialize(self):
        self.ioc.message.add(Application.NAME)
        self._thread = threading.currentThread()
        self._loop.create_task(self.__supervisor())
        self._loop.create_task(self.__start_server())

    def _finalize(self):
        self.ioc.message.remove(Application.NAME)

    @asyncio.coroutine
    def __start_server(self):
        admin = AdminServer(self.ioc)
        admin.start()
        self.ioc.workers.add('AdminServer', 'Core', admin)

    @asyncio.coroutine
    async def __supervisor(self):  # noqa E999
        while not self._halt.is_set():
            await asyncio.sleep(1)
            e = self.ioc.message.receive(Application.NAME)
            if not isinstance(e, ServerEvent):
                continue
            if e.message == ServerEvent.MESSAGE_QUIT:
                self.ioc.workers.stop()


class Server(Application):
    pass


class Daemonizer:
    """
    An Application daemonizer

    Usage: daemonize a subclassed Application class
    """
    def __init__(self,
                 app,
                 pidfile,
                 stdin='/dev/null',
                 stdout='/dev/null',
                 stderr='/dev/null'):
        self.__app = app
        self.__stdin = stdin
        self.__stdout = stdout
        self.__stderr = stderr
        self.__pidfile = pidfile

    def __daemonize(self):
        try:
            pid = os.fork()
            if pid > 0:
                # exit first parent
                sys.exit(0)
        except OSError as e:
            sys.stderr.write(
                'fork #1 failed: {:d} ({:})\n'.format(e.errno, e.strerror)
            )
            sys.exit(1)

        # decouple from parent environment
        os.chdir('/')
        os.setsid()
        os.umask(0)

        # do second fork
        try:
            pid = os.fork()
            if pid > 0:
                # exit from second parent
                sys.exit(0)
        except OSError as e:
            sys.stderr.write(
                'fork #2 failed: {:d} ({:})\n'.format(e.errno, e.strerror)
            )
            sys.exit(1)

        # redirect standard file descriptors
        sys.stdout.flush()
        sys.stderr.flush()

        with open(self.__stdin, 'r') as si:
            os.dup2(si.fileno(), sys.stdin.fileno())
        with open(self.__stdout, 'a+') as so:
            os.dup2(so.fileno(), sys.stdout.fileno())
        with file(self.__stderr, 'a+', 0) as se:
            os.dup2(se.fileno(), sys.stderr.fileno())

        # write pidfile
        atexit.register(self.__delpid)
        pid = str(os.getpid())
        file(self.__pidfile, 'w+').write('{:}\n'.format(pid))

    def __delpid(self):
        os.remove(self.__pidfile)

    def start(self, daemonize=True):
        """
        Start the daemon
        """
        # Check for a pidfile to see if the daemon already __runs
        try:
            pf = open(self.__pidfile, 'r')
            pid = int(pf.read().strip())
            pf.close()
        except IOError:
            pid = None

        if pid:
            message = "pidfile %s already exist. Daemon already running?\n"
            sys.stderr.write(message % self.__pidfile)
            sys.exit(1)

        # Start the daemon
        if daemonize:
            self.__daemonize()
        self.__app.run()

    def stop(self):
        """
        Stop the daemon
        """
        # Get the pid from the pidfile
        try:
            pf = file(self.__pidfile, 'r')
            pid = int(pf.read().strip())
            pf.close()
        except IOError:
            pid = None

        if not pid:
            message = "pidfile %s does not exist. Daemon not running?\n"
            sys.stderr.write(message % self.__pidfile)
            return  # not an error in a restart

        # Try killing the daemon process
        try:
            while 1:
                os.kill(pid, SIGTERM)
                time.sleep(0.1)
        except OSError as err:
            err = str(err)
            if err.find("No such process") > 0:
                if os.path.exists(self.__pidfile):
                    os.remove(self.__pidfile)
            else:
                print((str(err)))
                sys.exit(1)

    def restart(self):
        """
        Restart the daemon
        """
        self.stop()
        self.start()
