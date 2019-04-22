"""Module docstring."""
import os
import sys
import time
import atexit
import signal
import functools
import asyncio

from ..utils import Util
from ..const import Const
from ..ioc import ContainerAware
from ..starter import Starter


class Application(ContainerAware):
    """Main server application class."""

    def __init__(self, ioc):
        """Initialize app logger."""
        ContainerAware.__init__(self, ioc)
        self._applog = self.ioc.log.app

    def _initialize(self):
        loop = asyncio.get_event_loop()

        loop.add_signal_handler(
            signal.SIGINT, functools.partial(self.quiter, signal.SIGINT))

        loop.add_signal_handler(
            signal.SIGTERM, functools.partial(self.quiter, signal.SIGTERM))

        vault_file = Util.path(self.ioc.env['root'], Const.CNL_VAULT)
        if os.path.isfile(vault_file):
            self._applog.info(
                'Vault archive found. Initialize startup mode.')
        else:
            self._applog.info(
                'Vault archive NOT found. Initialize setup mode.')
            self.ioc.add('boot', lambda ioc: Starter().boot_server(
                self._listen(), port=self.ioc.env['port'], ioc=ioc))
            boot = self.ioc.boot

    def _finalize(self):
        self._applog.info('Shutting down server.')
        # self.ioc.executor.stop()
        self._applog.info('Server quitting.')

    def _listen(self):
        la = self.ioc.env['listen']
        if la == 'localhost':
            listen = 'localhost'
        elif la == 'loopback':
            listen = '127.0.0.1'
        elif la == 'hostname':
            listen = self.ioc.env['hostname']
        elif la == 'domain':
            listen = self.ioc.env['domain']
        elif la == 'ip':
            listen = self.ioc.env['ip']
        elif la == 'any':
            listen = ''
        else:
            listen = la
        return listen

    def quiter(self, signame):
        """
        Coroutine that waits for Quit.

        When the Quit event happens it raises a KeyboardInterrupt to stop the
        run_forever of the main event loop. Initiating the shutdown sequence.
        """
        self.ioc.quit.set()
        raise KeyboardInterrupt(signame)

    def run(self):
        """Run the server applications main loop."""
        self._applog.info('-------- STARTING SERVER --------')

        self._initialize()
        try:
            asyncio.get_event_loop().run_forever()
        except KeyboardInterrupt:
            pass
        except Exception as e:
            self._applog.critical(
                'Server crashed due to unhandled exception: %s' % e)
        self._finalize()

        self._applog.info('-------- EXITING SERVER --------')


class Daemonizer:
    """
    An Application daemonizer.

    Usage: daemonize a subclassed Application class
    """

    def __init__(self, app, pidfile,
                 stdin='/dev/null', stdout='/dev/null', stderr='/dev/null'):
        """Initialize the daemonizer."""
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
        """Start the daemon."""
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
        """Stop the daemon."""
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
            while True:
                os.kill(pid, signal.SIGTERM)
                time.sleep(.1)
        except OSError as err:
            err = str(err)
            if err.find("No such process") > 0:
                if os.path.exists(self.__pidfile):
                    os.remove(self.__pidfile)
            else:
                print((str(err)))
                sys.exit(1)

    def restart(self):
        """Restart the daemon."""
        self.stop()
        self.start()
