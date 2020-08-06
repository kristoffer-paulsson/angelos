#!/usr/bin/env python
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
"""Angelos build script."""
import inspect
import shutil
import subprocess
from pathlib import Path

from setuptools import setup, Command, find_namespace_packages


class VagrantBuild(Command):
    """Custom steps for develop command."""

    user_options = [
        ("target=", "t", "Build target."),
    ]

    def initialize_options(self):
        """Initialize options"""
        self.target = None

    def finalize_options(self):
        """Finalize options"""
        pass

    def run(self):
        self.do_vagrant()

    def do_vagrant(self):
        build = Path("./build").resolve()
        root = build.joinpath("vagrant")
        data = root.joinpath("data")

        build.mkdir(exist_ok=True)
        root.mkdir(exist_ok=True)
        data.mkdir(exist_ok=True)

        import angelos.meta.package
        provision = Path(inspect.getfile(angelos.meta.package)).parent
        shutil.copyfile(str(provision.joinpath("provision.py")), str(data.joinpath("provision.py")))
        shutil.copyfile(str(provision.joinpath("Vagrantfile")), str(root.joinpath("Vagrantfile")))

        subprocess.check_call("vagrant up", shell=True, cwd=str(root))


NAME = "angelos.meta"
VERSION = "1.0.0b1"
RELEASE = ""


config = {
    "name": NAME,
    "version": VERSION,
    "license": "MIT",
    "cmdclass": {
        "package": VagrantBuild,
    },
    "classifiers": [
        "Development Status :: 3 - Alpha",
        "Environment :: Console",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
    ],
    "install_requires": [],
    "package_dir": {"": "src"},
    "packages": find_namespace_packages(where="src", include=["angelos.*"]),
    "namespace_packages": ["angelos"],
    "python_requires": ">=3.6, <4",
}


setup(**config)