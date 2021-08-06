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
"""Module loader and inspector."""
import importlib
import inspect


class ModuleInspector:
    """Inspect the given module."""

    def __init__(self, module_name: str):
        self.__name = module_name
        self.__spec = importlib.util.find_spec(module_name)
        self.__module = None
        self.__classes = None
        self.__functions = None

    def _predicator(self, tester) -> callable:
        """Predicate generator."""
        return lambda member: tester(member) and member.__module__ == self.module.__name__

    @property
    def module(self):
        """Expose the module and load if necessary."""
        if not self.__module:
            self.__module = self.__spec.loader.load_module()
            self.__spec.loader.exec_module(self.__module)
        return self.__module

    @property
    def classes(self) -> list:
        """Expose the classes of the module and gather if necessary."""
        if not self.__classes:
            self.__classes = inspect.getmembers(self.module, self._predicator(inspect.isclass))
        return self.__classes

    @property
    def functions(self) -> list:
        """Expose the functions of the module and gather if necessary."""
        if not self.__functions:
            self.__functions = inspect.getmembers(
                self.module, lambda member: inspect.isfunction(member) and member.__module__ == self.module.__name__)
        return self.__functions