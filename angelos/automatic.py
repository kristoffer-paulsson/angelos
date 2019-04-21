import socket
import platform
import os
import sys
import sysconfig


class Automatic:
    def __init__(self):
        computer = socket.gethostname()
        hostname = computer.lower()
        ip = socket.gethostbyname(computer)
        domain = socket.getfqdn()

        platform.uname()
        platform.java_ver()
        platform.win32_ver()
        platform.mac_ver()
        platform.dist()

        os.getpid()
        os.getppid()
        os.uname()
        os.cpu_count()
        sys.platform
        sysconfig.get_platform()


('darwin', 'ios', 'android', 'win32', 'windows', 'linux', 'freebsd*')
