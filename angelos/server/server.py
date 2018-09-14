"""Docstring"""
import sys
import os
import atexit
import time
import threading
import asyncio
import logging
from signal import SIGTERM
from ..const import Const
from ..worker import Worker
from ..events import Message
from .admin import AdminServer


class Application(Worker):
    """Docstring"""

    def __init__(self, ioc):
        Worker.__init__(self, ioc)
        self.ioc.workers.add(Const.W_SUPERV_NAME, Const.G_CORE_NAME, self)
        self.log = ioc.log.err()

    def start(self):
        self.run()

    def _initialize(self):
        logging.info('#'*10 + 'Entering ' + self.__class__.__name__ + '#'*10)
        self.ioc.message.add(Const.W_SUPERV_NAME)
        self._thread = threading.currentThread()
        self.task(self.__supervisor)
        self.task(self.__start_server)

    def _finalize(self):
        self.ioc.message.remove(Const.W_SUPERV_NAME)
        logging.info('#'*10 + 'Leaving ' + self.__class__.__name__ + '#'*10)

    def _panic(self):
        logging.info('#'*10 + 'Panic ' + self.__class__.__name__ + '#'*10)
        self.ioc.message.send(Message(
            Const.W_ADMIN_NAME, Const.W_SUPERV_NAME, 1, {}))

    @asyncio.coroutine
    def __start_server(self):
        logging.info('#'*10 + 'Entering __start_server' + '#'*10)
        admin = AdminServer(self.ioc)
        admin.start()
        self.ioc.workers.add(Const.W_ADMIN_NAME, Const.G_CORE_NAME, admin)
        logging.info('#'*10 + 'Leaving __start_server' + '#'*10)

    @asyncio.coroutine
    async def __supervisor(self):  # noqa E999
        logging.info('#'*10 + 'Entering __supervisor' + '#'*10)
        while not self._halt.is_set():
            await asyncio.sleep(1)
            m = self.ioc.message.receive(Const.W_SUPERV_NAME)
            logging.info(m)
            if m is None:
                continue
            if m.message == 1:
                self.ioc.workers.stop()
        logging.info('#'*10 + 'Leaving __supervisor' + '#'*10)


class Server(Application):
    """Docstring"""
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
        with open(self.__stderr, 'a+', 0) as se:
            os.dup2(se.fileno(), sys.stderr.fileno())

        # write pidfile
        atexit.register(self.__delpid)
        pid = str(os.getpid())
        with open(self.__pidfile, 'w+') as pid:
            pid.write('{:}\n'.format(pid))

    def __delpid(self):
        os.remove(self.__pidfile)

    def start(self, daemonize=True):
        """
        Start the daemon
        """
        # Check for a pidfile to see if the daemon already __runs
        try:
            with open(self.__pidfile, 'r') as pf:
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
            with open(self.__pidfile, 'r') as pf:
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
