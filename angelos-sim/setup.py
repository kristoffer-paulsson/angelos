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
import os
import re
from glob import glob

from Cython.Build import cythonize
from setuptools import setup, find_namespace_packages, Extension
from sphinx.setup_command import BuildDoc


# TODO: Mitigate angelos-sim into test fixtures and scripts.


################################################################################


class LibraryScanner:
    """Scan directories for Cython *.pyx files and configure extensions to build."""

    def __init__(self, base_path: str, globlist: list = None, pkgdata: dict = None, data: dict = None):
        self.__base_path = base_path
        self.__globlist = globlist if globlist else ["**.pyx"]
        self.__pkgdata = pkgdata if pkgdata else {}
        self.__data = data if data else {
            "compiler_directives": {
                "language_level": 3,
                "embedsignature": True
            }
        }

    def scan(self) -> list:
        """Build list of Extensions to be cythonized."""
        glob_result = list()
        for pattern in self.__globlist:
            glob_path = os.path.join(self.__base_path, pattern)
            glob_result += glob(glob_path, recursive=True)

        extensions = list()
        for module in glob_result:
            package = re.sub("/", ".", module[len(self.__base_path) + 1:-4])
            data = self.__pkgdata[package] if package in self.__pkgdata else {}
            core = {"name": package, "sources": [module]}
            kwargs = {**self.__data, **data, **core}
            extensions.append(Extension(**kwargs))

        return extensions


################################################################################


NAME = "angelos.sim"
VERSION = "1.0.0b1"
RELEASE = ""

globlist = [
    "angelos/sim/**.pyx",
    "angelos/sim/**/*.pyx",
]

pkgdata = {
}

coredata = {
    "build_dir": "build",
    "cython_c_in_temp": True,
    "compiler_directives": {
        "language_level": 3,
        "embedsignature": True
    }
}

config = {
    "name": NAME,
    "version": VERSION,
    "license": "MIT",
    "package_dir": {"": "src"},
    "packages": find_namespace_packages(where="src", include=["angelos.*"]),
    "cmdclass": {
        "build_sphinx": BuildDoc
    },
    "command_options": {
        'build_sphinx': {
            "project": ("setup.py", NAME),
            "version": ("setup.py", VERSION),
            "release": ("setup.py", RELEASE),
            "source_dir": ("setup.py", "angelos-sim/docs")
        }
    },
    "ext_modules": cythonize(LibraryScanner("src", globlist, pkgdata, coredata).scan()),
}

setup(**config)
