# cython: language_level=3, linetrace=True
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
"""Extensions for application framework."""
import functools
import logging
import os
import signal
import sys
from argparse import ArgumentParser
from asyncio import Event

from angelos.base.app import Extension


cdef extern from "time.h" nogil:
    ctypedef int time_t
    time_t time(time_t*)

cdef long START_TIME = <long>time(NULL)


cdef class OptimizedLogRecord:
    """Log record replacement that is optimized."""

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


class Logger(Extension):
    """Sets up a logger."""

    def prepare(self, *args):
        logging.setLogRecordFactory(OptimizedLogRecord)
        logger = logging.getLogger()
        logger.setLevel(logging.DEBUG)

        file = logging.FileHandler(self._args.get("name", "unknown") + ".log")
        file.addFilter(self._filter_file)
        logger.addHandler(file)

        stream = logging.StreamHandler(sys.stderr)
        stream.addFilter(self._filter_stream)
        logger.addHandler(stream)

        return logger

    def _filter_file(self, rec: logging.LogRecord):
        return rec.levelname != "INFO"

    def _filter_stream(self, rec: logging.LogRecord):
        return rec.levelname == "INFO"


class Arguments(Extension):
    """Argument parser from the command line."""

    def arguments(self, parser: ArgumentParser):
        """Enhance argument parser."""

    def prepare(self, *args):
        parser = ArgumentParser(self._args.get("name", "Unknown program"))
        self.arguments(parser)
        return parser.parse_args()


class Quit(Extension):
    """Prepares a general quit/exit flag with an event."""

    EVENT = Event()

    def __init__(self):
        super().__init__()
        self.EVENT.clear()

    def prepare(self, *args):
        return self.EVENT


class Signal(Extension):
    """Configure witch signals to be caught and how to handle them. Override to get custom handling."""

    EXIT = signal.CTRL_C_EVENT if os.name == "nt" else signal.SIGINT
    TERM = signal.SIGWINCH

    def prepare(self, *args):
        loop = self.get_loop()

        if self._args.get("quit", False):
            loop.add_signal_handler(self.EXIT, functools.partial(self.quit))

        if self._args.get("term", False):
            loop.add_signal_handler(self.TERM, functools.partial(self.size_change))

    def quit(self):
        """Trigger the quit flag if Quit extension is used."""
        q = self.get_quit()
        if q:
            q.set()
        self.get_loop().remove_signal_handler(self.EXIT)

    def size_change(self):
        return NotImplemented