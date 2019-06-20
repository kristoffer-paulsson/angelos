# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Import and export commands."""

import uuid
import yaml

from .cmd import Command, Option
from ..policy import PGroup, PrintPolicy
from ..operation.export import ExportImportOperation


class PortfolioCommand(Command):
    """Work with portfolios."""

    abbr = """View/Import/Export portfolios and documentes."""
    description = """Use this command to work with documents and portfolios."""

    def __init__(self, io, facade):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, 'port', io)
        self.__facade = facade

    async def _command(self, opts):
        if opts['import']:
            await self.__import()
        elif opts['export']:
            await self.__export(opts['export'])
        elif opts['view']:
            await self.__view(opts['view'])
        elif opts['list']:
            await self.__list(opts['list'])
        else:
            pass

    async def __import(self):
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

    async def __export(self, entity_id):
        if entity_id == 'self':
            entity_id = self.__facade.portfolio.entity.id
        else:
            entity_id = uuid.UUID(entity_id)

        portfolio = await self.__facade.load_portfolio(
            entity_id, PGroup.SHARE_MED_COMMUNITY)
        self._io << ExportImportOperation.text_exp(portfolio)

    async def __view(self, entity_id):
        entity_id = uuid.UUID(entity_id)
        portfolio = await self.__facade.load_portfolio(
            entity_id, PGroup.SHARE_MED_COMMUNITY)

        if not portfolio:
            self._io << '\nInvalid data entered\n\n'
            return

        issuer, owner = portfolio.to_sets()
        for doc in issuer | owner:
            self._io << doc.__class__.__name__ + '\n'
            self._io << yaml.dump(doc.export_yaml())
            self._io << '\n\n'

    async def __list(self, search='*'):
        self._io << '\n'
        for doc in await self.__facade.list_portfolios(query=search):
            if not doc[1]:
                self._io << (PrintPolicy.entity_title(doc[0]) +
                             '; ' + str(doc[0].id) + '\n')
        self._io << '\n'

    def _rules(self):
        return {
            'exclusive': [
                'import', 'export', 'view', 'list',
                'revoke', 'verify', 'trust'],
            'option': [
                'import', 'export', 'view', 'list',
                'revoke', 'verify', 'trust'],
        }

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return [
            Option(
                'import',
                abbr='i',
                type=Option.TYPE_BOOL,
                help='Import documents to portfolio'),
            Option(
                'export',
                abbr='e',
                type=Option.TYPE_VALUE,
                help='Export portfolio'),
            Option(
                'view',
                abbr='v',
                type=Option.TYPE_VALUE,
                help='View portfolio'),
            Option(
                'list',
                abbr='l',
                type=Option.TYPE_VALUE,
                help='List portfolio entries',
                default='*'),
            Option(
                'revoke',
                abbr='r',
                type=Option.TYPE_VALUE,
                help='List portfolio statement'),
            Option(
                'verify',
                abbr='f',
                type=Option.TYPE_VALUE,
                help='Verify portfolio entity'),
            Option(
                'trust',
                abbr='t',
                type=Option.TYPE_VALUE,
                help='Trust portfolio entity'),
            ]

    @classmethod
    def factory(cls, **kwargs):
        """Create command with facade from IoC."""
        return cls(kwargs['io'], kwargs['ioc'].facade)


class ImportCommand(Command):
    """Import information to the Facade."""

    abbr = """Manual import to the Facade."""
    description = """Use this command to manually import documents and data."""

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
            elif opts['vault'] == 'list':
                for doc in await self.__facade.list_portfolios():
                    if not doc[1]:
                        self._io << (PrintPolicy.entity_title(doc[0]) +
                                     '; ' + str(doc[0].id) + '\n')

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
            choices=['self', 'list'],
            help='Confirm that you want to shutdown server')]

    @classmethod
    def factory(cls, **kwargs):
        """Create command with facade from IoC."""
        return cls(kwargs['io'], kwargs['ioc'].facade)
