# cython: language_level=3
"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Import and export commands."""
import pickle
import base64

from .cmd import Command, Option


class ImportCommand(Command):
    """Import information to the Facade."""

    abbr = """Manual import to the Facade."""
    description = """Use this command to manually import documents and data."""

    def __init__(self, io, facade):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, 'import', io)
        self.__facade = facade

    async def _command(self, opts):
        self._io << ('\nTo be implemented!\n')

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
                self._io << ('\n' + self.exporter(
                    'Identity', self.__facade.entity,
                    self.__facade.keys, self.__facade.network) + '\n')

        self._io << ('\nTo be implemented!\n')

    def exporter(self, name, *docs, meta=None):
        output = self.headline(name, '(Start)')
        data = base64.b64encode(pickle.dumps(docs)).decode('utf-8')
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
