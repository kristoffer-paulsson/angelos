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
from types import SimpleNamespace
from venv import EnvBuilder

from setuptools import Command


class AngelosEnvBuilder(EnvBuilder):
    def setup_scripts(self, context: SimpleNamespace) -> None:
        """Don't install activation scripts."""
        pass


class Environment(Command):
    """Setup virtual environment and install."""

    user_options = [
        ("path=", "p", "Virtual environment root."),
    ]

    def initialize_options(self):
        """Initialize options"""
        self.path = None

    def finalize_options(self):
        """Finalize options"""
        pass

    def run(self):
        major, minor, _, _, _ = sys.version_info
        PY_VER = "{0}.{1}".format(major, minor)

        path = str(Path(self.path).absolute())
        venv = AngelosEnvBuilder()
        venv.create(path)