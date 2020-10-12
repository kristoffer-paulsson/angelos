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
import os
import re
import subprocess
import sys
from os import PathLike
from pathlib import Path

from setuptools import setup, Command, Extension
from setuptools.command.develop import develop
from setuptools.command.install import install
from Cython.Build import cythonize


class SubPackages:
    """Subpackages to execute commands on."""

    NAMESPACES = {
        "angelos.meta": "angelos-meta",
        "angelos.psi": "angelos-psi",
        "angelos.common": "angelos-common",
        "angelos.bin": "angelos-bin",
        "angelos.document": "angelos-document",
        "angelos.archive7": "angelos-archive7",
        "angelos.lib": "angelos-lib",
        "angelos.server": "angelos-server",
    }

    def subpackage(self, command: list):
        """Deal with all subpackages."""
        work_dir = os.getcwd()
        prefix = str(Path(getattr(self, "prefix")).resolve()) if getattr(self, "prefix", None) else None
        for package, directory in self.NAMESPACES.items():
            try:
                path = str(Path(work_dir, directory).resolve())
                os.chdir(path)
                addition = ["--user"] if "--user" in sys.argv else []
                addition += ["--ignore-installed", "--prefix", prefix] if prefix else []
                with subprocess.Popen(
                        " ".join(command + addition),
                        stdout=sys.stdout,
                        stderr=sys.stderr,
                        shell=True
                ):
                    pass
            except Exception as exc:
                print("Oops, something went wrong installing", package)
                print(exc)
            finally:
                os.chdir(work_dir)


class CustomDevelop(develop, SubPackages):
    """Custom steps for develop command."""

    def run(self):
        """Run develop on namespace and subpackages."""
        develop.run(self)
        self.subpackage(["pip", "install", "-e", "."])


class CustomInstall(install, SubPackages):
    """Custom steps for install command."""

    def run(self):
        """Run install on namespace and subpackages."""
        install.run(self)
        self.subpackage(["pip", "install", "."])


class CustomEnvironment(Command, SubPackages):
    """Custom steps for setting up virtual environment command."""

    user_options = [
        ("prefix=", "p", "Virtual environment directory."),
        ("step=", "s", "Start from step X."),

    ]

    def initialize_options(self):
        """Initialize options"""
        self.prefix = None
        self.step = None

    def finalize_options(self):
        """Finalize options"""
        try:
            if not Path(self.prefix).exists():
                raise TypeError()
        except TypeError:
            print("Path is invalid")
            exit(1)

        if isinstance(self.step, str):
            matches = []
            for match in re.findall(r"""(\d+-\d+|\d+)""", self.step):
                if "-" in match:
                    se = match.split("-")
                    matches += list(range(int(se[0]), int(se[1])+1))
                else:
                    matches += [int(match)]
            if matches:
                self.step = matches
            else:
                print("Invalid steps")
                exit(1)

        if not self.step:
            self.step = list(range(1, 10+1))

    def process(self, cmd: str, work_dir: PathLike, env: dict = None):
        """Run subprocess and print output."""
        cur_dir = os.getcwd()
        try:
            os.chdir(work_dir)
            subprocess.call(cmd, cwd=str(work_dir), shell=True, env=env)
        except Exception as exc:
            print(exc)
        finally:
            os.chdir(cur_dir)

    def prepare(self):
        """Make preparations."""
        if 1 in self.step:
            print("##########  1_PREPARATIONS  ##########")
            self.path_install = Path(self.prefix).resolve()
            self.path_current = Path(os.curdir).resolve()
            self.path_meta = Path(os.curdir, self.NAMESPACES["angelos.meta"]).resolve()
            self.path_server = Path(os.curdir, self.NAMESPACES["angelos.server"]).resolve()
            self.path_bin = Path(self.path_install, "bin")
            self.path_python = Path(self.path_bin, "python3")

            self.env = {k: os.environ[k] for k in os.environ.keys() if k not in (
                "PYCHARM_MATPLOTLIB_INTERACTIVE", "IPYTHONENABLE", "PYDEVD_LOAD_VALUES_ASYNC",
                "__PYVENV_LAUNCHER__", "PYTHONUNBUFFERED", "PYTHONIOENCODING",
                "VERSIONER_PYTHON_VERSION", "PYCHARM_MATPLOTLIB_INDEX", "PYCHARM_DISPLAY_PORT",
                "PYTHONPATH"
            )}

            print("path_install:", str(self.path_install))
            print("path_current:", str(self.path_current))
            print("path_meta:", str(self.path_meta))
            print("path_server:", str(self.path_server))
            print("path_bin:", str(self.path_bin))
            print("path_python:", str(self.path_python))

            print("##########  1_PREPARATIONS_END  ##########")

    def create(self):
        """Create a python environment."""
        # 1. Compile and install python
        if 2 in self.step:
            print("##########  2_PYTHON_BUILD  ##########")
            self.process(
                "python setup.py vendor --prefix={0}".format(str(self.path_install)), self.path_server)
            print("##########  2_PYTHON_BUILD_END  ##########")

        # 2. Compile and install build requirements
        if 3 in self.step:
            print("##########  3_REQUIREMENTS_INSTALL  ##########")
            for pypi in ["pip", "setuptools", "wheel", "cython"]:
                self.process(
                    "{1} -m pip install {0} --upgrade".format(
                        pypi, str(self.path_python)), self.path_current, self.env)
            print("##########  3_REQUIREMENTS_INSTALL_END  ##########")

        # 3. Install angelos meta subpackage
        if 4 in self.step:
            print("##########  4_ANGELOS_META  ##########")
            self.process(
                "{0} -m pip install . --ignore-installed --prefix={1}".format(
                    str(self.path_python), str(self.path_install)),
                self.path_meta, self.env)
            print("##########  4_ANGELOS_META_END  ##########")

    def install(self):
        """Install angelos to environment."""
        # 4. Compile and install angelos entry point
        if 5 in self.step:
            print("##########  5_EXECUTABLE_BUILD  ##########")
            self.process(
                "{1} setup.py exe --name={0} --prefix={2}".format(
                    "angelos", str(self.path_python), str(self.path_install)),
                self.path_server, self.env)
            print("##########  5_EXECUTABLE_BUILD_END  ##########")

        # 5. Compile and install angelos binaries
        if 6 in self.step:
            print("##########  6_ANGELOS_BUILD  ##########")
            self.process(
                "{0} setup.py install --prefix={1}".format(str(self.path_python), str(self.path_install)),
                self.path_current, self.env)
            print("##########  6_ANGELOS_BUILD_END  ##########")

    def strip(self):
        """Strip all libraries and binaries from debug symbols."""
        # 6.
        if 7 in self.step:
            print("##########  7_STRIP_BINARIES  ##########")
            self.process(
                "strip -x -S $(find {} -type f -name \*.so -o -name \*.dll -o -name \*.a -o -name \*.dylib)".format(
                    str(self.path_install)),
                self.path_current, self.env)
            self.process(
                "strip -x -S $(find {} -type f)".format(str(self.path_bin)),
                self.path_current, self.env)
            print("##########  7_STRIP_BINARIES_END  ##########")

    def cleanup(self):
        """Clean up unnecessary artefacts."""
        # 7. Uninstall unnecessary requirements
        if 8 in self.step:
            print("##########  8_REQUIREMENTS_UNINSTALL  ##########")
            for pypi in ["cython", "wheel", "setuptools", "pip"]:
                self.process(
                    "{1} -m pip uninstall {0} --yes".format(pypi, str(self.path_python)),
                    self.path_current, self.env)
            print("##########  8_REQUIREMENTS_UNINSTALL_END  ##########")

        # 8. Remove unnecessary folders
        if 9 in self.step:
            print("##########  9_REMOVE_FOLDERS  ##########")
            self.process(
                "rm -fR {}".format(str(Path(self.path_install, "share"))),
                self.path_current, self.env)
            self.process(
                "rm -fR {}".format(str(Path(self.path_install, "include"))),
                self.path_current, self.env)
            print("##########  9_REMOVE_FOLDERS_END  ##########")

        # 9. Remove unused binaries and links
        if 10 in self.step:
            print("##########  10_REMOVE_BINARIES  ##########")
            self.process(
                "find . ! -name 'angelos' -and ! -name 'install' -and ! -name 'uninstall' -type f -exec rm -f {} +",
                self.path_bin.resolve(), self.env)
            self.process(
                "find . ! -name 'angelos' -type l -exec rm -f {} +",
                self.path_bin.resolve(), self.env)
            print("##########  10_REMOVE_BINARIES_END  ##########")

    def run(self):
        """Create a frozen standalone angelos server environment."""
        print("##########  VIRTUAL_ENVIRONMENT  ##########")
        self.prepare()
        self.create()
        self.install()
        self.strip()
        self.cleanup()
        print("##########  VIRTUAL_ENVIRONMENT_END  ##########")


NAME = "angelos"
VERSION = "1.0.0b1"
RELEASE = ""


config = {
    "name": NAME,
    "version": VERSION,
    "license": "MIT",
    "description": "A safe messaging system",
    "author": "Kristoffer Paulsson",
    "author_email": "kristoffer.paulsson@talenten.se",
    "long_description": "Ἄγγελος is a safe messenger system. Angelos means \"Carrier of a divine message.\"",
    # Path("./README.md").read_text(),
    "long_description_content_type": "text/markdown",
    "url": "https://github.com/kristoffer-paulsson/angelos",
    "cmdclass": {
        "develop": CustomDevelop,
        "install": CustomInstall,
        "venv": CustomEnvironment
    },
    "classifiers": [
        "Development Status :: 2 - Pre-Alpha",
        "Environment :: Console",
        "Environment :: Handhelds/PDA\'s",
        # "Environment :: MacOS X",
        # "Environment :: Win32 (MS Windows)",
        "Environment :: No Input/Output (Daemon)",
        # "Environment :: X11 Applications :: Gnome",
        "Framework :: AsyncIO",
        "Intended Audience :: Developers",
        # "Intended Audience :: End Users/Desktop",
        "Intended Audience :: Information Technology",
        "Intended Audience :: Religion",
        "Intended Audience :: System Administrators",
        "Intended Audience :: Telecommunications Industry",
        "License :: OSI Approved :: MIT License",
        "Operating System :: MacOS :: MacOS X",
        "Operating System :: Microsoft :: Windows",
        "Operating System :: POSIX",
        # "Programming Language :: C",
        "Programming Language :: Cython",
        "Programming Language :: Python :: 3.7",
        "Topic :: Communications :: Chat",
        "Topic :: Communications :: Email",
        "Topic :: Communications :: File Sharing",
        "Topic :: Documentation",
        "Topic :: Internet",
        "Topic :: Religion",
        "Topic :: Security",
        "Topic :: System :: Archiving",
        "Topic :: Utilities",
    ],
    "package_dir": {"": "src"},
    "packages": ["angelos"],
    "install_requires": ["cython"],
    "ext_modules": cythonize(
        Extension("angelos.data", ["src/angelos/data.pyx"]),
        build_dir="build",
        compiler_directives={
            "language_level": 3,
        }
    ),
    "python_requires": ">=3.6, <4",
}

setup(**config)
