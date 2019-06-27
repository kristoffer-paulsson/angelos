# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Import and export commands."""
import uuid
import yaml

from .cmd import Command, Option
from ..policy import PGroup, PrintPolicy, StatementPolicy
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
            await self.__export(opts['export'], opts['group'])
        elif opts['view']:
            await self.__view(opts['view'], opts['group'])
        elif opts['list']:
            await self.__list(opts['list'])
        else:
            pass

    async def __import(self):
        """"""
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
            try:
                await self.__facade.import_portfolio(portfolio)
            except OSError as e:
                await self.__facade.update_portfolio(portfolio)

    async def __export(self, entity_id, group):
        if entity_id == 'self':
            entity_id = self.__facade.portfolio.entity.id
        else:
            entity_id = uuid.UUID(entity_id)

        portfolio = await self.__facade.load_portfolio(
            entity_id, self.__group(group))
        portfolio.privkeys = None
        self._io << ExportImportOperation.text_exp(portfolio)

    async def __view(self, entity_id, group):
        entity_id = uuid.UUID(entity_id)
        portfolio = await self.__facade.load_portfolio(
            entity_id, self.__group(group))

        if not portfolio:
            self._io << '\nInvalid data entered\n\n'
            return

        portfolio.privkeys = None

        issuer, owner = portfolio.to_sets()
        for doc in issuer | owner:
            self._io << doc.__class__.__name__ + '\n'
            self._io << yaml.dump(doc.export_yaml())
            self._io << '\n\n'

        if portfolio.entity.id == self.__facade.portfolio.entity.id:
            return

        verified = StatementPolicy.validate_verified(
            self.__facade.portfolio, portfolio)
        trusted = StatementPolicy.validate_trusted(
            self.__facade.portfolio, portfolio)

        v_renewable = False
        t_renewable = False

        if verified:
            if verified.expires_soon():
                v_renewable = True
        if trusted:
            if trusted.expires_soon():
                t_renewable = True

        s1 = 'Create verified statement.'
        s2 = 'Renew verified statement.'
        s3 = 'Revoke verified statement'
        s4 = 'Create trusted statement'
        s5 = 'Renew trusted statement'
        s6 = 'Revoke trusted statement'

        do = await self._io.menu('Portfolio statement management', [
            self._io.dim(s1) if verified else s1,
            s2 if v_renewable else self._io.dim(s2),
            s3 if verified else self._io.dim(s3),
            self._io.dim(s4) if trusted else s4,
            s5 if t_renewable else self._io.dim(s5),
            s6 if trusted else self._io.dim(s6),
            'Continue',
        ])

        statement = None
        if do == 0 and not verified:
            statement = StatementPolicy.verified(
                self.__facade.portfolio, portfolio)
        elif do == 1 and v_renewable:
            statement = StatementPolicy.verified(
                self.__facade.portfolio, portfolio)
        elif do == 2 and verified:
            statement = StatementPolicy.revoked(
                self.__facade.portfolio, verified)
        elif do == 3 and not trusted:
            statement = StatementPolicy.trusted(
                self.__facade.portfolio, portfolio)
        elif do == 4 and t_renewable:
            statement = StatementPolicy.trusted(
                self.__facade.portfolio, portfolio)
        elif do == 5 and trusted:
            statement = StatementPolicy.revoked(
                self.__facade.portfolio, trusted)

        if statement:
            await self.__facade.docs_to_portfolios(set([statement]))
            self._io << '\nSaved statement changes to portfolio.\n'

    async def __list(self, search='*'):
        self._io << '\n'
        for doc in await self.__facade.list_portfolios(query=search):
            if not doc[1]:
                self._io << (PrintPolicy.entity_title(doc[0]) +
                             '; ' + str(doc[0].id) + '\n')
        self._io << '\n'

    def __group(self, group):
        if group == 'verify':
            return PGroup.VERIFIER
        elif group == 'min':
            return PGroup.SHARE_MIN_COMMUNITY
        elif group == 'med':
            return PGroup.SHARE_MED_COMMUNITY
        elif group == 'max':
            return PGroup.SHARE_MAX_COMMUNITY
        elif group == 'all':
            return PGroup.ALL
        else:
            return PGroup.SHARE_MED_COMMUNITY

    def _rules(self):
        return {
            'exclusive': [
                'import', 'export', 'view', 'list',
                'revoke', 'verify', 'trust'],
            'option': [
                'import', 'export', 'view', 'list',
                'revoke', 'verify', 'trust'],
            'group': [('export', 'view'), None, None, None]
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
                'group',
                abbr='g',
                type=Option.TYPE_CHOICES,
                choices=['verify', 'min', 'med', 'max', 'all'],
                default='med',
                help='Load portfolio group'),
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
