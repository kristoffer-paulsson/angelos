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
"""Automatic values about the digital environment."""
import os
import platform
import socket
import sys
from pathlib import Path

from angelos.common.misc import BaseData, Misc


class Platform(BaseData):
    """Platform information."""

    def __init__(self):
        (
            self.system,
            self.node,
            self.release,
            self.version,
            self.machine,
            self.processor,
        ) = platform.uname()

        self.java = platform.java_ver()[0]
        self.win = platform.win32_ver()[0]
        self.mac = platform.mac_ver()[0]


class Runtime(BaseData):
    """Runtime information."""

    def __init__(self):
        self.user = os.environ["USER"]
        self.pid = os.getpid()
        self.ppid = os.getppid()
        self.cpus = os.cpu_count()
        self.platform = sys.platform
        self.id = Misc.unique()


class Directories(BaseData):
    """Directories in the system"""
    def __init__(self):
        if self.system == "Darwin":
            (
                self.root_dir, self.run_dir, self.state_dir,
                self.logs_dir, self.conf_dir
            ) = self._macos()
        elif self.system == "Windows":
            (
                self.root_dir, self.run_dir, self.state_dir,
                self.logs_dir, self.conf_dir
            ) = self._windows()
        else:
            (
                self.root_dir, self.run_dir, self.state_dir,
                self.logs_dir, self.conf_dir
            ) = self._linux()


class Desktop(Directories):
    """Desktop computer directories for a user."""
    def __init__(self):
        Directories.__init__(self)

    def _macos(self):
        """Macos user directories."""
        app = self.name.capitalize()
        return (
            Path("/"),
            None,
            Path("~/Library/Application Support/{app}".format(app=app)).home(),
            Path("~/Library/Logs/{app}".format(app=app)).home(),
            Path("~/Library/Caches/{app}".format(app=app)).home()
        )

    def _windows(self):
        """Windows user directories."""
        app = self.name.capitalize()
        return (
            Path("C:/"),
            None,
            Path("C:/Users/{user}/AppData/Local/{author}/{app}".format(user=self.user, app=app, author=app)),
            Path("C:/Users/{user}/AppData/Local/{author}/{app}/Logs".format(user=self.user, app=app, author=app)),
            Path("C:/Users/{user}/AppData/Local/{author}/{app}".format(user=self.user, app=app, author=app))
        )

    def _linux(self):
        """Linux user directories."""
        app = self.name.lower()
        return (
            Path("/"),
            Path(os.environ["XDG_RUNTIME_DIR"]).home(),
            Path(os.environ["XDG_STATE_HOME"] or "~/.local/state/{app}".format(app=app)).home(),
            Path(os.environ["XDG_CACHE_HOME"] or "~/.cache/{app}/log".format(app=app)).home(),
            Path(os.environ["XDG_CONFIG_HOME"] or "~/.config/{app}".format(app=app)).home()
        )


class Server(Directories):
    """Server computer directories for the system."""
    def __init__(self):
        Directories.__init__(self)

    def _macos(self):
        """Macos server directories."""
        app = self.name.capitalize()
        return (
            Path("/"),
            None,
            Path("/Library/Application Support/{app}".format(app=app)),
            Path("/Library/Application Support/{app}/Logs".format(app=app)),
            Path("/Library/Application Support/{app}".format(app=app))
        )

    def _windows(self):
        """Windows server directories."""
        app = self.name.capitalize()
        return (
            Path("C:/"),
            None,
            Path("C:/ProgramData/{author}/{app}".format(app=app, author=app)),
            Path("C:/ProgramData/{author}/{app}/Logs".format(app=app, author=app)),
            Path("C:/ProgramData/{author}/{app}".format(app=app, author=app))
        )

    def _linux(self):
        """Linux server directories"""
        app = self.name.lower()
        return (
            Path("/"),
            Path("/run/{app}".format(app=app)),
            Path("/var/lib/{app}".format(app=app)),
            Path("/var/log/{app}".format(app=app)),
            Path("/etc/{app}".format(app=app))
        )


class Network(BaseData):
    """Automatic values about the network."""

    def __init__(self):
        name = socket.gethostname()
        self.hostname = name.lower()
        self.ip = Misc.ip()[0]
        self.domain = socket.getfqdn()


class Automatic(BaseData):
    """Automatic values about the system."""

    def __init__(self, name: str):
        """Generate the values and instantiate vars."""
        self.name = name

    def override(self, parser):
        """Override with parser values."""
        if parser:
            for key, value in vars(parser.args).items():
                if value or key not in self.__dict__:
                    self.__dict__[key] = value