# cython: language_level=3, linetrace=True
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
from angelos.server.cmd import Command, Option


class ProcessCommand(Command):
    """Start and shutdown server processes."""

    abbr = """Switch on and off internal processes."""
    description = """Use this command to start and shutdown processes in the angelos server from the terminal."""  # noqa E501

    def __init__(self, io, state):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "proc", io)
        self._state = state

    def _rules(self):
        return {
            "exclusive": [("clients", "nodes", "hosts")],
            "flag": [None, ("clients", "nodes", "hosts"), None, None],
            "clients": [None, None, ["flag"], None],
            "nodes": [None, None, ["flag"], None],
            "hosts": [None, None, ["flag"], None],
        }

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return [
            Option(
                "clients",
                abbr="c",
                type=Option.TYPE_BOOL,
                help="Turn on/off the Clients server process",
            ),
            Option(
                "nodes",
                abbr="n",
                type=Option.TYPE_BOOL,
                help="Turn on/off the Nodes server process",
            ),
            Option(
                "hosts",
                abbr="s",
                type=Option.TYPE_BOOL,
                help="Turn on/off the Hosts server process",
            ),
            Option(
                "flag",
                abbr="f",
                type=Option.TYPE_CHOICES,
                choices=["on", "off"],
                help="Whether to turn ON or OFF",
            ),
        ]

    async def _command(self, opts):
        if opts["clients"]:
            await self.flip("clients", opts["flag"])
        elif opts["nodes"]:
            await self.flip("nodes", opts["flag"])
        elif opts["hosts"]:
            await self.flip("hosts", opts["flag"])
        else:
            self._io << (
                "\nClients: {0}.".format(
                    "ON" if self._state.position("clients") else "OFF"
                )
            )
            self._io << (
                "\nNodes: {0}.".format(
                    "ON" if self._state.position("nodes") else "OFF"
                )
            )
            self._io << (
                "\nHosts: {0}.\n".format(
                    "ON" if self._state.position("hosts") else "OFF"
                )
            )

    async def flip(self, state, flag):
        """Flip a certain state."""
        if state not in self._state.states:
            self._io << ('\nState "{0}" not configured.\n\n'.format(state))
            return

        if flag == "on":
            flag = True
        else:
            flag = False

        pos = self._state.position(state)
        if flag and not pos:
            self._io << ('\nTurned state "{0}" ON.\n\n'.format(state))
            self._state(state, flag)
        elif not flag and pos:
            self._io << ('\nTurned state "{0}" OFF.\n\n'.format(state))
            self._state(state, flag)
        else:
            self._io << (
                '\nState "{0}" already {1}.\n\n'.format(
                    state, "ON" if pos else "OFF"
                )
            )

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs["io"], kwargs["ioc"].state)