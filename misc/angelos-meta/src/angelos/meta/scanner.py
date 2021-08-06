#
# Copyright (c) 2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""Scanners that comply with namespace packages.

Rules to implement:
    Enforce method/function return typing:
        regex: "def [\w].*\):"
"""
import os
from pathlib import Path
from typing import Union


class NamespacePackageScanner:
    """A scanner for namespace packages."""

    def __init__(self, namespace: str, root: Path = None):
        self.__namespace = namespace
        self.__root = root.resolve() if root else Path(os.curdir).resolve()
        self.__root_parts_cnt = len(self.__root.parts)

    def pkg_iter(self) -> None:
        """Iterator over all namespace packages"""
        for pkg_path in self.__root.glob(self.__namespace + "-*/"):
            yield pkg_path

    def pkg_name(self, pkg_path: Path) -> str:
        """Convert package path into its name."""
        return pkg_path.parts[-1]

    @property
    def packages(self) -> list:
        """Property over all namespace packages."""
        return [self.pkg_name(pkg_path) for pkg_path in self.pkg_iter()]

    def _dir_iter(self, pkg_path: Path, rel_path: Union[str, list], pattern: str) -> None:
        """Internal iterator for directories and extensions in a namespace package."""
        for file_path in pkg_path.joinpath(rel_path).rglob(pattern):
            yield file_path

    def mod_iter(self, pkg_path: Path) -> None:
        """Iterate over all modules in named namespace package."""
        for mod_path in self._dir_iter(pkg_path, "src", "*.pyx"):
            yield mod_path

    def tests_iter(self, pkg_path: Path) -> None:
        """Iterate over all tests in named namespace package."""
        for mod_path in self._dir_iter(pkg_path, "tests", "test_*.py"):
            yield mod_path

    def mod_imp_path(self, mod_path: Path) -> str:
        """Converts module path to full package name."""
        return ".".join(mod_path.parts[self.__root_parts_cnt+2:-1] + (mod_path.stem,))