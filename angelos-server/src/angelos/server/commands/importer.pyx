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
import pprint

from angelos.server.cmd import Command
from angelos.lib.operation.export import ExportImportOperation


class ImportCommand(Command):
    """Import information to the Facade."""

    abbr = """Manual import to the Facade."""
    description = """Use this command to manually import documents and data."""

    def __init__(self, io, facade):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "import", io)
        self.__facade = facade

    async def _command(self, opts):
        data = await self._io.multiline("Import portfolio")
        portfolio = ExportImportOperation.text_imp(data)

        if not portfolio:
            self._io << "\nInvalid data entered\n\n"
            return

        issuer, owner = portfolio.to_sets()
        for doc in issuer | owner:
            self._io << doc.__class__.__name__ + "\n"
            pprint.pprint(doc.export_yaml(), self._io.stdout)
            self._io << "\n\n"

        imp = await self._io.confirm(
            "Confirm that you want to import this portfolio"
        )
        if imp:
            await self.__facade.storage.vault.import_portfolio(portfolio)

    @classmethod
    def factory(cls, **kwargs):
        """Create command with facade from IoC."""
        return cls(kwargs["io"], kwargs["ioc"].facade)