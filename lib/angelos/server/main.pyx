# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Daemonize starter."""
import os
import sys
import time
import atexit
import signal

from .parser import Parser


class Application:
    """Application wrapper."""

    def __init__(self):
        """Initialize wrapper."""
        self.app = None

    def run(self):
        """Start and run application."""
        from .server import Server
        Server().run()


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
        with open(self.__stderr, 'wb+', 0) as se:
            os.dup2(se.fileno(), sys.stderr.fileno())

        # write pidfile
        atexit.register(self.__delpid)
        pid = str(os.getpid())
        with open(self.__pidfile, 'w+') as pidf:
            pidf.write('{:}\n'.format(pid))

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


def start():
    """Start server application."""
    app = Application()
    parser = Parser()

    if parser.args.daemon == 'start':
        Daemonizer(
            app, '/tmp/angelos.pid').start()
    elif parser.args.daemon == 'stop':
        Daemonizer(
            app, '/tmp/angelos.pid').stop()
    else:
        app.run()
