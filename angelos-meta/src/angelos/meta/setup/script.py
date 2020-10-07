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
from pathlib import Path

from setuptools import Command


class Script(Command):
    """Compile the executable"""

    user_options = [
        ("name=", "n", "Name of the script."),
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
        dist = str(Path(self.prefix, "bin").resolve()) if self.prefix else str(Path("./bin").absolute())
        home = str(Path("./").absolute())

        subprocess.check_call(
            "cp {0:s} {2}/{1}".format(
                Path(home, "scripts", self.name + "_entry_point.sh"), self.name, dist), cwd=home, shell=True)
