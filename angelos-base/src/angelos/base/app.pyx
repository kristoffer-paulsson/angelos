# cython: language_level=3
#
# Copyright (c) 2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
import logging
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
        self._current = None

    def __getattr__(self, name: str):
        if name not in self._instances:
            if name not in self.CONFIG:
                raise NameError("Couldn't find module: {}".format(name))
            elif callable(self.CONFIG[name]):
                self._current = name
                self._instances[name] = self.CONFIG[name].__call__(self)
            else:
                raise AttributeError("Couldn't find attribute: {}".format(name))
        return self._instances[name]

    def __ior__(self, other):
        if self._current in self._instances:
            self._instances[self._current] = other


class Container(ContainerMixin):
    pass


class Extension(Module):
    """Application extension module initializer."""
    def __init__(self, **kwargs: dict):
        self._args = kwargs
        self._app = None

    def __call__(self, app: "Application", *args):
        self._app = app
        print("Prepace", self.__class__.__name__)
        return self.prepare(*args)

    def prepare(self, *args):
        raise NotImplementedError()

    def get_loop(self):
        """Applications event loop."""
        try:
            return self._app.loop
        except NameError:
            return asyncio.get_event_loop()

    def get_quit(self):
        """Global quit flag."""
        try:
            return self._app.quit
        except NameError:
            return None


class Application(ContainerMixin):
    """Application class to base a program on for pre-prepared initialization."""

    def __init__(self):
        ContainerMixin.__init__(self)
        self._return_code = 0

    @property
    def return_code(self) -> int:
        """Application return code."""
        return self._return_code

    def _stop(self):
        asyncio.get_event_loop().stop()

    def run(self):
        self._initialize()
        try:
            loop = asyncio.get_event_loop()
            loop.create_task(self.start())
            loop.create_task(self.stop())
            loop.run_forever()
        except KeyboardInterrupt:
            logging.info("Exiting because of unknown reason.")
        except RuntimeError as exc:
            self._return_code = 3
            logging.critical("Critical runtime error, CRASHED!", exc_info=exc)
        finally:
            loop.run_until_complete(loop.shutdown_asyncgens())
            loop.close()
        self._finalize()
        return self._return_code

    async def start(self):
        """Initialize and start main program sequence."""
        pass

    async def stop(self):
        """Wait for quit signal and tear down program."""
        pass
