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
"""Dealing with subpackages."""
from pathlib import Path


class NamespacePackage:
    """Namespace package operations."""
    def __init__(self, name: str, ns: str):
        self.__name = name
        self.__ns = ns

        self.__path = Path("./", self.__ns + "-" + self.__name).resolve()

    def exists(self):
        """See if namespace packages exists."""
        return self.__path.exists()

    def create(self):
        if self.exists():
            raise OSError("Namespace package {} already exists.".format(self.__ns + "-" + self.__name))

        self.__path.mkdir(parents=True, exist_ok=True)
        self.__path.joinpath("setup.py").touch(exist_ok=True)
        self.__path.joinpath("README.md").touch(exist_ok=True)
        self.__path.joinpath("requirements.txt").touch(exist_ok=True)
        self.__path.joinpath("tox.ini").touch(exist_ok=True)
        code_path = self.__path.joinpath("src", self.__ns, self.__name)
        code_path.mkdir(parents=True, exist_ok=True)
        code_path.joinpath("__init__.py").touch(exist_ok=True)
        code_path.joinpath("__init__.pxd").touch(exist_ok=True)
        code_path.parent.joinpath("__init__.pxd").touch(exist_ok=True)
        bin_path = self.__path.joinpath("bin")
        bin_path.mkdir(parents=True, exist_ok=True)
        bin_path.joinpath(".gitkeep").touch(exist_ok=True)
        tests_path = self.__path.joinpath("tests")
        tests_path.mkdir(parents=True, exist_ok=True)
        tests_path.joinpath(".gitkeep").touch(exist_ok=True)
        req_path = self.__path.joinpath("requirements")
        req_path.mkdir(parents=True, exist_ok=True)
        req_path.joinpath("dev.txt").touch(exist_ok=True)
        req_path.joinpath("prod.txt").touch(exist_ok=True)
        req_path.joinpath("pkg.txt").touch(exist_ok=True)

