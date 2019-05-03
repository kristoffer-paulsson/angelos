# cython: language_level=3
"""Automatic values about the digital environment."""
import socket
import platform
import os
import sys

import plyer

from .utils import Util


class Automatic:
    """Automatic values about the system."""

    def __init__(self):
        """Generate the values and instanciate vars."""
        self.name = socket.gethostname()
        self.hostname = self.name.lower()
        self.ip = socket.gethostbyname(self.name)
        self.domain = socket.getfqdn()

        (self.p_system, self.p_node, self.p_release, self.p_version,
            self.p_machine, self.p_processor) = platform.uname()
        self.p_java = platform.java_ver()[0]
        self.p_win = platform.win32_ver()[0]
        self.p_mac = platform.mac_ver()[0]
        self.p_linux = platform.dist()[0]

        self.pid = os.getpid()
        self.ppid = os.getppid()
        self.cpus = os.cpu_count()
        self.platform = sys.platform

        self.id = plyer.uniqueid.id.decode()

        self.app_dir = Util.app_dir()
        self.usr_dir = Util.usr_dir()
        self.exe_dir = Util.exe_dir()


"""
('darwin', 'ios', 'android', 'win32', 'windows', 'linux', 'freebsd*')
"""
