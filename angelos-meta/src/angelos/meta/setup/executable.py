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
import subprocess
import sys
import tempfile
from pathlib import Path

from setuptools import Command


class Executable(Command):
    """Compile the executable"""

    user_options = [
        ("name=", "n", "Entry name."),
        ("prefix=", "p", "Possible prefix where to link against.")
    ]

    def initialize_options(self):
        """Initialize options"""
        self.name = None
        self.prefix = None

    def finalize_options(self):
        """Finalize options"""
        pass

    def run(self):
        major, minor, _, _, _ = sys.version_info
        PY_VER = "{0}.{1}".format(major, minor)

        config = str(
            Path(self.prefix, "bin", "python{}-config".format(PY_VER)).resolve()
        ) if self.prefix else "python{}-config".format(PY_VER)
        dist = str(Path(self.prefix, "bin").resolve()) if self.prefix else str(Path("./bin").absolute())

        temp = tempfile.TemporaryDirectory()

        temp_name = str(Path(temp.name, self.name).absolute())
        home = str(Path("./").absolute())

        cflags = subprocess.check_output(
            "{} --cflags".format(config), stderr=subprocess.STDOUT, shell=True).decode()

        # Debian 10 specific
        cflags = cflags.replace("-specs=/usr/share/dpkg/no-pie-compile.specs", "")

        # https://docs.python.org/3.8/whatsnew/3.8.html#debug-build-uses-the-same-abi-as-release-build
        if major == 3 and minor >= 8:
            ldflags = subprocess.check_output(
                "{} --ldflags --embed".format(config), stderr=subprocess.STDOUT, shell=True).decode()
        else:
            ldflags = subprocess.check_output(
                "{} --ldflags".format(config), stderr=subprocess.STDOUT, shell=True).decode()

        subprocess.check_call(
            "cython --embed -3 -o {}.c ./scripts/{}_entry_point.pyx".format(
                temp_name, self.name), cwd=home, shell=True)

        subprocess.check_call(
            "gcc -o {0}.o -c {0}.c {1}".format(
                temp_name, cflags), cwd=temp.name, shell=True)

        subprocess.check_call(
            "gcc -o {0}/{1} {2}.o {3}".format(
                dist, self.name, temp_name, ldflags), cwd=home, shell=True)

        temp.cleanup()
