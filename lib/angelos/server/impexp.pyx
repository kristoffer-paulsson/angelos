"""Import and export commands."""
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
        self._io << ('\nTo be implemented!\n')

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
