# cython: language_level=3
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
"""Library scanner to scan for all *.pyx files in a hierarchy."""
import re
import glob
import pathlib

from setuptools import Extension


class LibraryScanner:
    """Scan directories for Cython *.pyx files and configure extensions to build."""

    def __init__(self, base_path: str, glob: list = None, extra: dict = None, basic: dict = None):
        self.__base_path = base_path
        self.__globlist = glob if glob else ["**.pyx"]
        self.__pkgdata = extra if extra else dict()
        self.__data = basic if basic else dict()

    def scan(self) -> list:
        """Build list of Extensions to be cythonized."""
        glob_result = list()
        for pattern in self.__globlist:
            glob_path = str(pathlib.Path(self.__base_path, pattern))
            glob_result += glob.glob(glob_path, recursive=True)

        extensions = list()
        for module in glob_result:
            package = re.sub("/", ".", module[len(self.__base_path) + 1:-4])
            data = self.__pkgdata[package] if package in self.__pkgdata else {}
            core = {"name": package, "sources": [module]}
            kwargs = {**self.__data, **data, **core}
            extensions.append(Extension(**kwargs))

        return extensions

    def list(self) -> list:
        """Build list of modules found."""
        glob_result = list()
        for pattern in self.__globlist:
            glob_path = str(pathlib.Path(self.__base_path, pattern))
            glob_result += glob.glob(glob_path, recursive=True)

        modules = list()
        for module in glob_result:
            package = re.sub("/", ".", module[len(self.__base_path) + 1:-4])
            modules.append(package)

        return modules