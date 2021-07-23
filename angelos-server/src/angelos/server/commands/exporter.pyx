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
from angelos.lib.operation.export import ExportImportOperation
from angelos.lib.policy.format import PrintPolicy
from angelos.lib.policy.portfolio import PGroup


class ExportCommand(Command):
    """Export information from the Facade."""

    abbr = """Manual export from the Facade."""
    description = """Use this command to manually export documents and data."""

    def __init__(self, io, facade):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "export", io)
        self.__facade = facade

    async def _command(self, opts):
        if opts["vault"]:
            if opts["vault"] == "self":
                portfolio = await self.__facade.storage.vault.load_portfolio(
                    self.__facade.data.portfolio.entity.id,
                    PGroup.SHARE_MED_COMMUNITY,
                )
                self._io << ExportImportOperation.text_exp(portfolio)
            elif opts["vault"] == "list":
                for doc in await self.__facade.storage.vault.list_portfolios():
                    if not doc[1]:
                        self._io << (
                            PrintPolicy.entity_title(doc[0])
                            + "; "
                            + str(doc[0].id)
                            + "\n"
                        )

    def _rules(self):
        return {"exclusive": ["vault"], "option": ["vault"]}

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return [
            Option(
                "vault",
                abbr="v",
                type=Option.TYPE_CHOICES,
                choices=["self", "list"],
                help="Confirm that you want to shutdown server",
            )
        ]

    @classmethod
    def factory(cls, **kwargs):
        """Create command with facade from IoC."""
        return cls(kwargs["io"], kwargs["ioc"].facade)