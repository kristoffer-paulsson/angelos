# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Import and export commands."""
import base64
import re

import yaml

from .cmd import Command, Option
from ..policy import PGroup, PortfolioPolicy


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
        portfolio = self.importer(data)

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

    def importer(self, data):
        match = re.findall(self.regex, data, re.MULTILINE)
        if len(match) != 1:
            return None
        data = match[0]
        return PortfolioPolicy.imports(base64.b64decode(data))

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
                self._io << ('\n' + self.exporter(
                    'Identity', portfolio) + '\n')

    def exporter(self, name, portfolio, meta=None):
        output = self.headline(name, '(Start)')
        data = base64.b64encode(
            PortfolioPolicy.exports(portfolio)).decode('utf-8')
        output += '\n' + '\n'.join(
            [data[i:i+79] for i in range(0, len(data), 79)]) + '\n'
        output += self.headline(name, '(End)')
        return output

    def headline(self, title, filler=''):
        title = ' ' + title + ' ' + filler + ' '
        line = '-' * 79
        offset = int(79/2 - len(title)/2)
        return line[:offset] + title + line[offset + len(title):]

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
