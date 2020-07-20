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
from angelos.cmd import Command
from libangelos.misc import Misc


class EnvCommand(Command):
    """Work with environment variables."""

    abbr = """Work with environment valriables."""
    description = (
        """Use this command to display the environment variables."""
    )  # noqa E501

    def __init__(self, io, env):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "env", io)
        self.__env = env

    async def _command(self, opts):
        self._io << ("\nEnvironment variables:\n" + "-" * 79 + "\n")
        self._io << "\n".join(Misc.recurse_env(self.__env))
        self._io << "\n" + "-" * 79 + "\n\n"

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs["io"], kwargs["ioc"].env)