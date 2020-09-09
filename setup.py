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
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace
from venv import EnvBuilder

import pip
from setuptools import setup, Command
from setuptools.command.develop import develop
from setuptools.command.install import install


class NamespacePackageMixin:
    """Install namespace packages."""

    NAMESPACES = {
        "angelos.meta": "angelos-meta/",
        "angelos.common": "angelos-common/",
        "angelos.bin": "angelos-bin/",
        "angelos.document": "angelos-document/",
        "angelos.archive7": "angelos-archive7/",
        "angelos.lib": "angelos-lib/",
        "angelos.server": "angelos-server/",
    }

    def namespace_packages(self, develop: bool = False):
        """Use pip to install all microlibraries."""
        work_dir = os.getcwd()
        prefix = Path(self.path).absolute() if hasattr(self, "path") else None
        for key, value in self.NAMESPACES.items():
            try:
                os.chdir(os.path.join(work_dir, value))
                addition = ["--user"] if "--user" in sys.argv else []
                addition = ["--ignore-installed", "--prefix", prefix] if prefix else []
                if develop:
                    pip.main(["install", "-e", "."] + addition)
                else:
                    pip.main(["install", "."] + addition)
            except Exception as exc:
                print("Oops, something went wrong installing", key)
                print(exc)
            finally:
                os.chdir(work_dir)


class CustomDevelop(develop, NamespacePackageMixin):
    """Custom steps for develop command."""

    def run(self):
        develop.run(self)
        self.namespace_packages(True)


class CustomInstall(install, NamespacePackageMixin):
    """Custom steps for install command."""

    def run(self):
        install.run(self)
        self.namespace_packages()


class AngelosEnvBuilder(EnvBuilder):
    def setup_scripts(self, context: SimpleNamespace) -> None:
        """Don't install activation scripts."""
        pass


class CustomEnvironment(Command, NamespacePackageMixin):
    """Custom steps for setting up virtual environment command."""

    user_options = [
        ("path=", "p", "Virtual environment directory."),
    ]

    def initialize_options(self):
        """Initialize options"""
        self.path = None

    def finalize_options(self):
        """Finalize options"""
        pass

    def run(self):
        path_install = str(Path(self.path).resolve())
        path_current = str(Path(os.curdir).resolve())
        path_meta = str(Path(os.curdir, self.NAMESPACES["angelos.meta"]).resolve())
        path_server = str(Path(os.curdir, self.NAMESPACES["angelos.server"]).resolve())

        env = {k: os.environ[k] for k in os.environ.keys() if k not in (
            "PYCHARM_MATPLOTLIB_INTERACTIVE", "IPYTHONENABLE", "PYDEVD_LOAD_VALUES_ASYNC",
            "__PYVENV_LAUNCHER__", "PYTHONUNBUFFERED", "PYTHONIOENCODING",
            "VERSIONER_PYTHON_VERSION", "PYCHARM_MATPLOTLIB_INDEX", "PYCHARM_DISPLAY_PORT",
            "PYTHONPATH"
        )}

        # Compile and install python
        subprocess.check_call(
            "python setup.py vendor --prefix={}".format(path_install),
            cwd=path_server,
            shell=True
        )

        # Compile and install build requirements
        for pypi in ["pip", "setuptools", "wheel", "cython"]:
            subprocess.run(
                "{1}/bin/python3 -m pip install {0} --upgrade".format(pypi, path_install),
                cwd=path_current,
                shell=True,
                env=env
            )

        # Compile and install angelos meta subpackage
        subprocess.run(
            "{0}/bin/python3 -m pip install . --ignore-installed --prefix={0}".format(path_install),
            cwd=path_meta,
            shell=True,
            env=env
        )

        # Compile and install angelos entry point
        subprocess.run(
            "{1}/bin/python3 setup.py exe --name={0} --prefix={1}".format("angelos", path_install),
            cwd=path_server,
            shell=True,
            env=env
        )

        # Compile and install angelos binaries
        subprocess.run(
            "{0}/bin/python3 setup.py install --prefix={0}".format(path_install),
            cwd=path_current,
            shell=True,
            env=env
        )

        # Strip all angelos binaries
        subprocess.run(
            "strip -x -S $(find {} -type f -name \*.so -o -name \*.dll -o -name \*.a -o -name \*.dylib)".format(
                path_install), cwd=path_current, shell=True, env=env)
        subprocess.run(
            "strip -x -S $(find {}/bin -type f)".format(
                path_install), cwd=path_current, shell=True, env=env)

        # Generate virtual environment
        # env = AngelosEnvBuilder()
        # env.create(path)

        # Install and compile angelos server to environment
        # install.run(self)
        # self.namespace_packages()

        # Strip symbols from binaries in the environment


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
    "install_requires": [],
    "python_requires": ">=3.6, <4",
}

setup(**config)
