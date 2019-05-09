# cython: language_level=3
"""Automatic values about the digital environment."""
import socket
import platform
import os
import sys

import plyer

from .utils import Util


class BaseAuto:
    pass


class Opts(BaseAuto):
    def __init__(self, parser):
        for k, v in vars(parser.args).items():
            self.__dict__[k] = v


class Dir(BaseAuto):
    def __init__(self):
        app = Util.app_dir()

        if '/usr/local/bin' in app:
            self.stem = os.path.dirname(os.path.dirname(os.path.dirname(app)))
        if '/usr/bin' in app:
            self.stem = os.path.dirname(os.path.dirname(app))
        elif '/bin' in app:
            self.stem = os.path.dirname(app)

        # Binary install directory
        self.executable = app
        # Current users directory
        self.home = Util.usr_dir()
        # Server root directory
        self.root = os.path.join(self.stem, 'var/lib/angelos')
        # Logging directory
        self.log = os.path.join(self.stem, 'var/log/angelos')
        # Current working directory
        self.current = Util.exe_dir()


class Sys(BaseAuto):
    def __init__(self):
        (self.system, self.node, self.release, self.version,
            self.machine, self.processor) = platform.uname()
        self.java = platform.java_ver()[0]
        self.win = platform.win32_ver()[0]
        self.mac = platform.mac_ver()[0]


class Net(BaseAuto):
    def __init__(self, name):
        self.hostname = name.lower()
        self.ip = socket.gethostbyname(name)
        self.domain = socket.getfqdn()


class Automatic(BaseAuto):
    """Automatic values about the system."""

    def __init__(self, parser=None):
        """Generate the values and instanciate vars."""
        self.name = socket.gethostname()
        self.pid = os.getpid()
        self.ppid = os.getppid()
        self.cpus = os.cpu_count()
        self.platform = sys.platform
        self.id = plyer.uniqueid.id.decode()

        self.sys = Sys()
        self.dir = Dir()
        self.net = Net(self.name)

        if parser:
            self.opts = Opts(parser)
        else:
            self.opts = None


"""
('darwin', 'ios', 'android', 'win32', 'windows', 'linux', 'freebsd*')
"""
