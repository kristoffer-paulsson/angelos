# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Automatic values about the digital environment."""
import logging
import os
import platform
import socket
import sys

from libangelos.misc import Misc
from libangelos.utils import Util


class BaseAuto:
    """Baseclass."""
    pass


class Opts(BaseAuto):
    """Automatic values about the options."""
    def __init__(self, parser):
        for k, v in vars(parser.args).items():
            self.__dict__[k] = v


class Dir(BaseAuto):
    """Automatic values about the File system."""

    def __init__(self, app_name):
        app = Util.app_dir()
        self.stem = ""

        if "/usr/local/bin" in app:
            self.stem = os.path.dirname(os.path.dirname(os.path.dirname(app)))
        if "/usr/bin" in app:
            self.stem = os.path.dirname(os.path.dirname(app))
        elif "/bin" in app:
            self.stem = os.path.dirname(app)

        # Binary install directory
        self.executable = app
        # Current users directory
        self.home = Util.usr_dir()
        # Server root directory
        self.root = os.path.join(self.stem, "var/lib/" + app_name)
        # Logging directory
        self.log = os.path.join(self.stem, "var/log/" + app_name)
        # Current working directory
        self.current = Util.exe_dir()


class Sys(BaseAuto):
    """Automatic values about the platform."""
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


class Net(BaseAuto):
    """Automatic values about the network."""

    def __init__(self):
        name = socket.gethostname()
        self.hostname = name.lower()
        try:
            self.ip = \
            (([ip for ip in socket.gethostbyname_ex(socket.gethostname())[2] if not ip.startswith("127.")] or [
                [(s.connect(("1.1.1.1", 1)), s.getsockname()[0], s.close()) for s in
                 [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1]]) + ["127.0.0.1"])[0]
        except socket.gaierror as e:
            logging.warning("Unknown server name")
            self.ip = None
        self.domain = socket.getfqdn()


class Automatic(BaseAuto):
    """Automatic values about the system."""

    def __init__(self, app_name, parser=None):
        """Generate the values and instantiate vars."""
        self.name = socket.gethostname()
        self.pid = os.getpid()
        self.ppid = os.getppid()
        self.cpus = os.cpu_count()
        self.platform = sys.platform
        self.id = Misc.unique()

        self.sys = Sys()
        self.dir = Dir(app_name)
        self.net = Net()

        if parser:
            self.opts = Opts(parser)
        else:
            self.opts = None


"""
('darwin', 'ios', 'android', 'win32', 'windows', 'linux', 'freebsd*')
"""
