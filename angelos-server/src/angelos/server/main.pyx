# cython: language_level=3
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""Angelos service starter and maintainer."""
import os
import signal
import time
import traceback
from multiprocessing import Process
from pathlib import Path

from angelos.server.parser import Parser

# TODO: Make all of angelos use pathlib instead of os.path

# TODO: Implement windows version:
#   https://gist.github.com/guillaumevincent/d8d94a0a44a7ec13def7f96bfb713d3f
#   https://github.com/meatballs/AnvilUplinkWindows


class PidFile:
    """Representation of a pid-file in /tmp."""

    def __init__(self, filename: str):
        self.__filename = Path("/tmp/{}.pid".format(filename))
        self.__running = False
        self.__pid = 0

        self.get()

    @property
    def running(self) -> bool:
        """Running status."""
        return self.__running

    @property
    def pid(self) -> int:
        """Process id."""
        return self.__pid

    @property
    def file(self) -> str:
        """Pid file path."""
        return str(self.__filename)

    def get(self) -> int:
        """Get pid from pid-file if any.

        Returns 0 if no pid.
        """
        if self.__filename.is_file():
            with open(self.__filename, "r") as pid_file:
                self.__pid = int(pid_file.read())
                self.__running = True
        else:
            self.__pid = 0
            self.__running = False

        return self.__pid

    def put(self, pid: int):
        """Write pid-file"""
        if not self.__filename.is_file():
            with open(self.__filename, "w") as pid_file:
                pid_file.write(str(pid))
                self.__pid = pid
                self.__running = True
        else:
            raise RuntimeError("Pid file already exists.")

    def remove(self):
        """Remove pid-file."""
        if self.__filename.is_file():
            self.__filename.unlink()
            self.__pid = 0
            self.__running = False


class ServerProcess(Process):
    """Server process forking class."""

    def __init__(self):
        Process.__init__(self)
        self.__pid_file = PidFile("angelos")

    def run(self):
        """Run server daemon control sequence."""
        pid = os.fork()
        if (pid != 0):
            return

        self.__pid_file.put(self.pid)
        from angelos.server.server import Server
        server = Server()
        server.run()
        self.__pid_file.remove()

        exit(server.return_code)


def cmd_start(pid_file):
    """Start background server process."""
    if pid_file.running:
        print("Angelos is already running with pid {}, pid-file {}.".format(
            pid_file.pid, pid_file.file))
        return

    ServerProcess().start()

def cmd_stop(pid_file):
    """Stop background server process."""
    if not pid_file.running:
        print("Angelos has no pid-file.")
        return
    try:
        while True:
            os.kill(pid_file.pid, signal.SIGTERM)
            time.sleep(0.1)
    except ProcessLookupError as e:
        pass

def cmd_runner(pid_file) -> int:
    """Angelos foreground server process."""
    if pid_file.running:
        print("Angelos is already running with pid {}, pid-file {}.".format(
            pid_file.pid, pid_file.file))
        return
    try:
        pid_file.put(os.getpid())
        from angelos.server.server import Server
        server = Server()
        server.run()
        pid_file.remove()
    except Exception as exc:
        print("Critical error. ({})".format(exc))
        traceback.print_exception(type(exc), exc, exc.__traceback__)
        pid_file.remove()

    return server.return_code

def start() -> int:
    """Start server application."""
    parser = Parser()
    pid_file = PidFile("angelos")

    if parser.args.daemon == "start":
        cmd_start(pid_file)
    elif parser.args.daemon == "stop":
        cmd_stop(pid_file)
    elif parser.args.daemon == "restart":
        cmd_stop(pid_file)
        cmd_start(pid_file)
    else:
        return cmd_runner(pid_file)

    return 0
