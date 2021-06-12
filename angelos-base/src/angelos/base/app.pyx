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
import logging
import os
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
    def __init__(self, **kwargs: dict):
        self._args = kwargs
        self._app = None

    def __call__(self, app: "Application", *args):
        self._app = app
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
            logging.critical("Critical runtime error, CRASHED!", exc_info=exc)
        finally:
            loop.run_until_complete(loop.shutdown_asyncgens())
            loop.close()
        self._finalize()

    async def start(self):
        """Initialize and start main program sequence."""
        pass

    async def stop(self):
        """Wait for quit signal and tear down program."""
        pass


cdef extern from "time.h" nogil:
    ctypedef int time_t
    time_t time(time_t*)

cdef long START_TIME = <long>time(NULL)


cdef class OptimizedLogRecord:

    cdef dict __dict__;

    cdef public str name;
    cdef public str msg;
    cdef public tuple args;
    cdef public str levelname;
    cdef public int levelno;
    cdef public str pathname;
    cdef public str filename;
    cdef public str module;
    cdef public object exc_info;
    cdef public str exc_text;
    cdef public object stack_info;
    cdef public int lineno;
    cdef public str funcName;
    cdef public long created;
    cdef public long msecs;
    cdef public long relativeCreated;
    cdef public str thread;
    cdef public str threadName;
    cdef public str processName;
    cdef public str process;

    def __cinit__(self):
        self.exc_text = None
        self.msecs = 0
        self.thread = None
        self.threadName = None
        self.processName = "MainProcess"
        self.process = None

    def __init__(self, name, level, pathname, lineno, msg, args, exc_info, func=None, sinfo=None, **kwargs):
        filename = os.path.basename(pathname)
        self.init(
            str(name),
            level,
            logging.getLevelName(level),
            pathname,
            filename,
            os.path.splitext(filename)[0],
            lineno,
            str(msg),
            tuple(args[0].values() if (args and len(args) == 1 and isinstance(args[0], dict) and args[0]) else args),
            exc_info,
            func,
            sinfo
        )

    cdef inline void init(
            self,
            str name,
            int level,
            str levelname,
            str pathname,
            str filename,
            str module,
            int lineno,
            str msg,
            tuple args,
            object exc_info,
            str func,
            object sinfo
    ):
        self.name = name
        self.msg = msg
        self.args = args
        self.levelname = levelname
        self.levelno = level
        self.pathname = pathname
        self.filename = filename
        self.module = module
        self.exc_info = exc_info
        self.stack_info = sinfo
        self.lineno = lineno
        self.funcName = func
        self.created = <long>time(NULL)
        self.relativeCreated = (self.created - START_TIME) * 1000

    def __repr__(self):
        return "<OptimizedLogRecord: %s, %s, %s, %s, \"%s\">" % (
            self.name, self.levelno, self.pathname, self.lineno, self.msg)

    cpdef str getMessage(self):
        """Merged user supplied message."""
        msg = str(self.msg)
        if self.args:
            msg = msg % self.args
        return msg