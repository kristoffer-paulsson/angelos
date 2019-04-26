"""Server commands."""
import os
import signal
import asyncio
import time
import datetime
import binascii

import libnacl

from ..utils import Util
from ..error import Error
from ..const import Const
from .cmd import Command, Option
from ..facade.facade import (
    PersonServerFacade, MinistryServerFacade, ChurchServerFacade)


class SetupCommand(Command):
    """Prepare and setup the server."""

    short = """Setup the facade with entity."""
    description = """Create or import an entity to configure the facade and node."""  # noqa E501
    msg_start = """
Setup command will lead you through the process of setting up an angelos
server. If you are creating a new entity with a new domain you have to go
through the process of configuring entity documents. Otherwise if you already
have an entity and a domain with working nodes, you need to import entity
documents and connect to the nodes on the current domain network.
"""

    def __init__(self, io, root):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, 'setup', io)
        self._root = root

    async def _command(self, opts):
        """Do entity setup."""
        self._io._stdout.write(self.msg_start)
        do = await self._io.menu('Select an entry', [
            'Create new entity',
            'Import existing entity'
        ], True)

        if do == 0:
            # Collect information for the data entity
            subdo, entity_data = await self.do_new()
            # Select server role
            r = await self._io.menu('What role should the server have?', [
                'Primary server',
                'Backup server'
            ], True)

            if r == 0:
                role = Const.A_ROLE_PRIMARY
            elif r == 1:
                role = Const.A_ROLE_BACKUP

            # Generate master key
            secret = libnacl.secret.SecretBox().hex_sk()
            self._io._stdout.write(
                'This is the Master key for this entity.\n' +
                'Make a backup, don\'t loose it!\n\n' +
                secret.decode() + '\n\n'
            )
            await self._io.presskey()
            # Verify master key
            s2 = await self._io.prompt('Enter the master key as verification!')

            if secret.decode() != s2:
                raise RuntimeError('Master key mismatch')

            if subdo == 0:
                facade = await PersonServerFacade.setup(
                    self._root, binascii.unhexlify(secret), role, entity_data)
            elif subdo == 1:
                facade = await MinistryServerFacade.setup(
                    self._root, binascii.unhexlify(secret), role, entity_data)
            elif subdo == 2:
                facade = await ChurchServerFacade.setup(
                    self._root, binascii.unhexlify(secret), role, entity_data)

        elif do == 1:
            docs = await self.do_import()
            return

    async def do_new(self):
        """Let user select what entity to create."""
        do = await self._io.menu('What type of entity should be created?', [
            'Person',
            'Ministry',
            'Church'
        ], True)

        if do == 0:
            return (0, await self.do_person())
        elif do == 1:
            return (1, await self.do_ministry())
        elif do == 2:
            return (2, await self.do_church())

    async def do_person(self):
        """Collect person entity data."""
        self._io._stdout.write(
            'It is necessary to collect information for the person entity.\n')
        valid = False
        data = {
            'given_name': None,
            'family_name': None,
            'names': [],
            'born': None,
            'sex': None
        }

        while True:
            do = await self._io.menu('Person entity data, (* = mandatory)', [
                '{m} {t:15} {c:4} {v}'.format(
                    m='*', t='First name',
                    c='OK' if bool(data['given_name']) else 'N/A',
                    v=data['given_name']),
                '{m} {t:15} {c:4} {v}'.format(
                    m='*', t='Family name',
                    c='OK' if bool(data['family_name']) else 'N/A',
                    v=data['family_name']),
                '{m} {t:15} {c:4} {v}'.format(
                    m='*', t='Middle names',
                    c='OK' if bool(data['names']) else 'N/A', v=data['names']),
                '{m} {t:15} {c:4} {v}'.format(
                    m='*', t='Birth date',
                    c='OK' if bool(data['born']) else 'N/A', v=data['born']),
                '{m} {t:15} {c:4} {v}'.format(
                    m='*', t='Sex',
                    c='OK' if bool(data['sex']) else 'N/A', v=data['sex']),
                '  Reset'
            ] + (['  Continue'] if valid else []))

            if do == 0:
                name = await self._io.prompt('Given name')
                data['given_name'] = name
                data['names'].append(name)
            elif do == 1:
                data['family_name'] = await self._io.prompt('Family name')
            elif do == 2:
                data['names'].append(await self._io.prompt('One (1) middle name'))  # noqa E501
            elif do == 3:
                data['born'] = await self._io.prompt(
                    'Birth date (YYYY-MM-DD)', t=datetime.date.fromisoformat)
            elif do == 4:
                data['sex'] = await self._io.choose(
                    'Biological sex', ['man', 'woman', 'undefined'])
            elif do == 5:
                data = {
                    'given_name': None,
                    'family_name': None,
                    'names': [],
                    'born': None,
                    'sex': None
                }
            elif do == 6:
                break

            if all(data) and data['given_name'] in data['names']:
                valid = True
            else:
                valid = False

        return data

    async def do_ministry(self):
        """Collect ministry entity data."""
        pass  # Just cut and paset from do_person and adjust

    async def do_church(self):
        """Collect church entity data."""
        pass  # Just cut and paset from do_person and adjust

    async def do_import(self):
        """Import entity from seed vault."""
        self._io._stdio.write('importing entities not implemented.')

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs['io'], kwargs['ioc'].env['root'])


class EnvCommand(Command):
    """Work with environment variables."""

    short = """Work with environment valriables."""
    description = """Use this command to display the environment variables."""  # noqa E501

    def __init__(self, io, env):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, 'env', io)
        self.__env = env

    async def _command(self, opts):
            self._io._stdout.write(
                '\nEnvironment variables:\n' + '-'*79 + '\n')
            self._io._stdout.write('\n'.join([
                '%s: %s' % (k, v) for k, v in self.__env.items()]))
            self._io._stdout.write('\n' + '-'*79 + '\n\n')

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs['io'], kwargs['ioc'].env)


class QuitCommand(Command):
    """Shutdown the angelos server."""

    short = """Shutdown the angelos server"""
    description = """Use this command to shutdown the angelos server from the terminal."""  # noqa E501

    def __init__(self, io):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, 'quit', io)

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return [Option(
            'yes',
            short='y',
            type=Option.TYPE_BOOL,
            help='Confirm that you want to shutdown server')]

    async def _command(self, opts):
        if opts['yes']:
            self._io._stdout.write(
                '\nStarting shutdown sequence for the Angelos server.\n\n')
            asyncio.ensure_future(self._quit())
            for t in ['3', '.', '.', '2', '.', '.', '1', '.', '.', '0']:
                self._io._stdout.write(t)
                time.sleep(.333)
            raise Util.exception(Error.CMD_SHELL_EXIT)
        else:
            self._io._stdout.write(
                '\nYou didn\'t confirm shutdown sequence. Use --yes/-y.\n\n')

    async def _quit(self):
        await asyncio.sleep(5)
        os.kill(os.getpid(), signal.SIGINT)


"""
class ServerCommand(Command):
    short = 'Operates the servers runstate.'
    description = With the server command you can operate the servers run
state. you can "start", "restart" and "shutdown" the softaware using the
options available. "shutdown" requires you to confirm with the "yes"
option."

    def __init__(self, message):
        Command.__init__(self, 'server')
        Util.is_type(message, Events)
        self.__events = message

    def _options(self):
        return[
            Option(
                'start', type=Option.TYPE_BOOL,
                help='Elevates the servers run state into operational mode'),
            Option('restart', type=Option.TYPE_BOOL,
                   help='Restarts the server'),
            Option('shutdown', type=Option.TYPE_BOOL,
                   help='Shuts down the server'),
            Option('yes', short='y', type=Option.TYPE_BOOL,
                   help='Use to confirm "shutdown"'),
        ]

    def _command(self, opts):
        if opts['start']:
            self._stdout.write(
                '"start" operation not implemented.' + Shell.EOL)

        elif opts['restart']:
            self._stdout.write(
                '"restart" operation not implemented.' + Shell.EOL)

        elif opts['shutdown']:
            if opts['yes']:
                self._stdout.write('Commencing operation "shutdown".' +
                                   Shell.EOL + 'Good bye!' + Shell.EOL)
                self.__events.send(Message(
                    Const.W_ADMIN_NAME, Const.W_SUPERV_NAME, 1, {}))
                for r in range(5):
                    self._stdout.write('.')
                    time.sleep(1)
                raise CmdShellExit()
            else:
                self._stdout.write(
                    'operation "shutdown" not confirmed.' + Shell.EOL)

        else:
            self._stdout.write(
                'No operation given. Type <server> -h for help.' + Shell.EOL)

    @staticmethod
    def factory(**kwargs):
        Util.is_type(kwargs['ioc'], Container)
        return ServerCommand(kwargs['ioc'].message)
"""
