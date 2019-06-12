# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Import and export commands."""

import yaml

from .cmd import Command, Option
from ..policy import PGroup
from ..operation.export import ExportImportOperation


class ImportCommand(Command):
    """Import information to the Facade."""

    abbr = """Manual import to the Facade."""
    description = """Use this command to manually import documents and data."""

    regex = r'----[\n\r]([a-zA-Z0-9+/\n\r]+={0,3})[\n\r]----'

    def __init__(self, io, facade):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, 'import', io)
        self.__facade = facade

    async def _command(self, opts):
        data = await self._io.multiline('Import portfolio')
        portfolio = ExportImportOperation.text_imp(data)

        if not portfolio:
            self._io << '\nInvalid data entered\n\n'
            return

        issuer, owner = portfolio.to_sets()
        for doc in issuer | owner:
            self._io << doc.__class__.__name__ + '\n'
            self._io << yaml.dump(doc.export_yaml())
            self._io << '\n\n'

        imp = await self._io.confirm(
            'Confirm that you want to import this portfolio')
        if imp:
            await self.__facade.import_portfolio(portfolio)

    @classmethod
    def factory(cls, **kwargs):
        """Create command with facade from IoC."""
        return cls(kwargs['io'], kwargs['ioc'].facade)


class ExportCommand(Command):
    """Export information from the Facade."""

    abbr = """Manual export from the Facade."""
    description = """Use this command to manually export documents and data."""

    def __init__(self, io, facade):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, 'export', io)
        self.__facade = facade

    async def _command(self, opts):
        if opts['vault']:
            if opts['vault'] == 'self':
                portfolio = await self.__facade.load_portfolio(
                    self.__facade.portfolio.entity.id,
                    PGroup.SHARE_MED_COMMUNITY)
                self._io << ExportImportOperation.text_exp(portfolio)

    def _rules(self):
        return {
            'exclusive': ['vault'],
            'option': ['vault']
        }

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return [Option(
            'vault',
            abbr='v',
            type=Option.TYPE_CHOICES,
            choices=['self'],
            help='Confirm that you want to shutdown server')]

    @classmethod
    def factory(cls, **kwargs):
        """Create command with facade from IoC."""
        return cls(kwargs['io'], kwargs['ioc'].facade)
