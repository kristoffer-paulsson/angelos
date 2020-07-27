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
import asyncio
import os
import signal
import time

from angelos.server.cmd import Command, Option
from angelos.lib.error import Error
from angelos.common.utils import Util


class QuitCommand(Command):
    """Shutdown the angelos server."""

    abbr = """Shutdown the angelos server"""
    description = """Use this command to shutdown the angelos server from the terminal."""  # noqa E501

    def __init__(self, io, state):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "quit", io)
        self._state = state

    def _rules(self):
        return {"depends": ["yes"]}

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return [
            Option(
                "yes",
                abbr="y",
                type=Option.TYPE_BOOL,
                help="Confirm that you want to shutdown server",
            )
        ]

    async def _command(self, opts):
        if opts["yes"]:
            self._io << (
                "\nStarting shutdown sequence for the Angelos server.\n\n"
            )
            self._state("all", False)
            asyncio.ensure_future(self._quit())
            for t in ["3", ".", ".", "2", ".", ".", "1", ".", ".", "0"]:
                self._io << t
                time.sleep(0.333)
            raise Error.exception(Error.CMD_SHELL_EXIT)
        else:
            self._io << (
                "\nYou didn't confirm shutdown sequence. Use --yes/-y.\n\n"
            )

    async def _quit(self):
        await asyncio.sleep(5)
        os.kill(os.getpid(), signal.SIGINT)

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs["io"], kwargs["ioc"].state)