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
from configparser import ConfigParser
from pathlib import Path

from Cython.Build import cythonize
from Cython.Compiler.Options import get_directive_defaults
from angelostools.pyxscanner import PyxScanner
from angelostools.setup import Vendor
from angelostools.setup.executable import Executable
from angelostools.setup.script import Script
from angelostools.setup.vendor import VendorCompile
from setuptools import setup, find_namespace_packages
from setuptools.command.develop import develop
from setuptools.command.install import install


class CustomDevelop(develop):
    """Custom steps for develop command."""

    def run(self):
        develop.run(self)


class CustomInstall(install):
    """Preparations and adaptions of building the app."""

    def run(self):
        """Carry out preparations and adaptions."""
        install.run(self)


class VendorCompilePython(VendorCompile):
    """Compile and install Python binary."""

    EXCLUDE = (
        "PYCHARM_MATPLOTLIB_INTERACTIVE", "IPYTHONENABLE", "PYDEVD_LOAD_VALUES_ASYNC",
        "__PYVENV_LAUNCHER__", "PYTHONUNBUFFERED", "PYTHONIOENCODING",
        "VERSIONER_PYTHON_VERSION", "PYCHARM_MATPLOTLIB_INDEX", "PYCHARM_DISPLAY_PORT",
        "PYTHONPATH"
    )

    _env = None

    def build(self):
        """Build sources."""
        self._env = {k: os.environ[k] for k in os.environ.keys() if k not in self.EXCLUDE}

        subprocess.run(
            "./configure --enable-optimization --with-lto --prefix={}".format(self._prefix),
            cwd=self._work, shell=True, env=self._env
        )

        subprocess.run("make", cwd=self._work, shell=True, env=self._env)
        # subprocess.run("make test", cwd=self._work, shell=True, env=self._env)

    def install(self):
        """Install binaries."""
        subprocess.run(
            "make install".format(self._prefix), cwd=self._work, shell=True, env=self._env)


NAME = "angelos.server"
config = ConfigParser()
config.read(Path(__file__).absolute().parents[1].joinpath("project.ini"))
VERSION = config.get("common", "version")
RELEASE = config.get("common", "release")
PYTHON = config.get("common", "python")

directive_defaults = get_directive_defaults()
directive_defaults['language_level'] = config.getint("cython", "language_level")
directive_defaults['linetrace'] = config.getboolean("cython", "linetrace")

scan = {
    "glob": [
        str(Path("angelos/server/*.pyx")),
        str(Path("angelos/server/**/*.pyx")),
    ],
    "extra": {
    },
    "basic": {
        "extra_compile_args": ["-DCYTHON_TRACE_NOGIL=1" if config.getboolean("cython", "linetrace") else ""],
    }
}

config = {
    "name": NAME,
    "version": VERSION,
    "license": "MIT",
    "cmdclass": {
        "develop": CustomDevelop,
        "install": CustomInstall,
        "exe": Executable,
        "script": Script,
        "vendor": Vendor
    },
    "command_options": {
        "exe": {
            "name": ("", "angelos")
        },
        "vendor": {
            "base_dir": ("", str(Path(__file__).parent.absolute())),
            "compile": ("", [
                {
                    "class": VendorCompilePython,
                    "name": "python",
                    "download": "https://www.python.org/ftp/python/3.8.5/Python-3.8.5.tgz",
                    "local": "Python-3.8.5.tgz",
                    "internal": "Python-3.8.5",
                    "check": str(Path("/nowhere")),
                }
            ]),
        }
    },
    "classifiers": [
        "Development Status :: 4 - Beta",
        "Environment :: No Input/Output (Daemon)",
        "Framework :: AsyncIO",
        "Intended Audience :: System Administrators",
        "Intended Audience :: Information Technology",
        "Intended Audience :: Religion",
        "Intended Audience :: Telecommunications Industry",
        "License :: OSI Approved :: MIT License",
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
    "install_requires": [
        # "angelos.common", "angelos.bin", "angelos.document", "angelos.lib", "angelos.archive7",
        "asyncssh"
    ],
    "package_dir": {"": "src"},
    "packages": find_namespace_packages(where="src", include=["angelos.*"]),
    "namespace_packages": ["angelos"],
    "ext_modules": cythonize(
        PyxScanner(str(Path("./src")), **scan).scan(),
        build_dir="build",
    ),
    "python_requires": PYTHON,
}

setup(**config)
