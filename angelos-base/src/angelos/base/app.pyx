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
"""Application framework for async network utilities."""
import asyncio
from collections.abc import Callable


class Module(Callable):
    """Module is used as a baseclass for container service module initializers."""

    def __init__(self, **kwargs):
        pass

    def __call__(self, *args):
        pass


class ContainerMixin:
    """Mixin to implement IoC compatible functionality.

    CONFIG is a dictionary of already initialized modules, the module itself instantiate the service to be used.
    """

    def __init__(self):
        if not isinstance(self.CONFIG, dict):
            raise TypeError("Container CONFIG must be dict, is: {}".format(type(self.CONFIG)))
        self._instances = dict()

    def __getattr__(self, name: str):
        if name not in self._instances:
            if name not in self.CONFIG:
                raise NameError("Couldn't find module: {}".format(name))
            elif callable(self.CONFIG[name]):
                self._instances[name] = self.CONFIG[name].__call__(self)
            else:
                raise AttributeError("Couldn't find attribute: {}".format(name))
        return self._instances[name]


class Container(ContainerMixin):
    pass


class Extension(Module):
    """Application extension module initializer."""
    def __init__(self, **kwargs):
        self._args = kwargs


class Application(ContainerMixin):
    """Application class to base a program on for pre-prepared initialization."""

    def __init__(self):
        ContainerMixin.__init__(self)

    def run(self):
        self._initialize()
        try:
            loop = asyncio.get_event_loop()
            loop.create_task(self.start())
            loop.create_task(self.stop())
            loop.run_forever()
        except KeyboardInterrupt:
            print("Exiting because of unknown reason.")
        self._finalize()

    async def start(self):
        """Initialize and start main program sequence."""
        pass

    async def stop(self):
        """Wait for quit signal and tear down program."""
        pass