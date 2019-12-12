# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Server commands."""
import asyncio
import binascii
import datetime
import logging
import os
import signal
import time

import libnacl
from angelos.cmd import Command, Option
from libangelos.automatic import BaseAuto
from libangelos.const import Const
from libangelos.error import Error
from libangelos.facade.facade import Facade
from libangelos.operation.setup import SetupPersonOperation, SetupChurchOperation, SetupMinistryOperation
from libangelos.policy.types import PersonData, MinistryData, ChurchData
from libangelos.utils import Util


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


class SetupCommand(Command):
    """Prepare and setup the server."""

    abbr = """Setup the facade with entity."""
    description = (
        """Create or import an entity to configure the facade and node."""
    )  # noqa E501
    msg_start = """
Setup command will lead you through the process of setting up an angelos
server. If you are creating a new entity with a new domain you have to go
through the process of configuring entity documents. Otherwise if you already
have an entity and a domain with working nodes, you need to import entity
documents and connect to the nodes on the current domain network.
"""

    def __init__(self, io, root, ioc):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "setup", io)
        self._root = root
        self._ioc = ioc

    async def _command(self, opts):
        """Do entity setup."""
        try:
            if isinstance(self._ioc.facade, Facade):
                self._io << "\nServer already running.\n\n"
                return

            vault_file = Util.path(self._ioc.env["dir"].root, Const.CNL_VAULT)
            if os.path.isfile(vault_file):
                self._io << "\n\nServer already setup.\n\n"
                return

            self._io << self.msg_start
            do = await self._io.menu(
                "Select an entry",
                ["Create new entity", "Import existing entity"],
                True,
            )

            if do == 0:
                # Collect information for the data entity
                subdo, entity_data = await self.do_new()
                # Select server role
                r = await self._io.menu(
                    "What role should the server have?",
                    ["Primary server", "Backup server"],
                    True,
                )

                if r == 0:
                    role = Const.A_ROLE_PRIMARY
                elif r == 1:
                    role = Const.A_ROLE_BACKUP

                # Generate master key
                secret = libnacl.secret.SecretBox().sk
                self._io << (
                    "This is the Master key for this entity.\n"
                    + "Make a backup, don't loose it!\n\n"
                    + binascii.hexlify(secret).decode()
                    + "\n\n"
                )
                await self._io.presskey()
                # Verify master key
                key = await self._io.prompt(
                    "Enter the master key as verification!"
                )

                if secret != binascii.unhexlify(key.encode()):
                    raise RuntimeError("Master key mismatch")

                os.makedirs(self._root, exist_ok=True)
                if subdo == 0:
                    portfolio = SetupPersonOperation.create(entity_data, server=True)
                    facade = await Facade.setup(self._root, secret, role, True, portfolio=portfolio)
                elif subdo == 1:
                    portfolio = SetupMinistryOperation.create(entity_data, server=True)
                    facade = await Facade.setup(self._root, secret, role, True, portfolio=portfolio)
                elif subdo == 2:
                    portfolio = SetupChurchOperation.create(entity_data, server=True)
                    facade = await Facade.setup(self._root, secret, role, True, portfolio=portfolio)

                self._ioc.facade = facade

            elif do == 1:
                raise NotImplementedError("Import to be implemented")
                # docs = await self.do_import()

            self._io << (
                "You just de-encrypted and loaded the Facade. Next step in\n"
                + "boot sequence is to start the "
                + "services and the Admin console.\n"
                + "Meanwhile you will be logged out from the Boot console.\n"
            )
            await self._io.presskey()
            asyncio.ensure_future(self._switch())
        except Exception as e:
            logging.exception("Error: %s" % e)

        raise Util.exception(Error.CMD_SHELL_EXIT)

    async def do_new(self):
        """Let user select what entity to create."""
        do = await self._io.menu(
            "What type of entity should be created?",
            ["Person", "Ministry", "Church"],
            True,
        )

        if do == 0:
            return (0, await self.do_person())
        elif do == 1:
            return (1, await self.do_ministry())
        elif do == 2:
            return (2, await self.do_church())

    async def do_person(self):
        """Collect person entity data."""
        self._io << (
            "It is necessary to collect information for the person entity.\n"
        )
        valid = False
        data = PersonData()
        data.given_name = None
        data.family_name = None
        data.names = []
        data.born = None
        data.sex = None

        while True:
            do = await self._io.menu(
                "Person entity data, (* = mandatory)",
                [
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="First name",
                        c="OK" if bool(data.given_name) else "N/A",
                        v=data.given_name,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="Family name",
                        c="OK" if bool(data.family_name) else "N/A",
                        v=data.family_name,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="Middle names",
                        c="OK" if bool(data.names) else "N/A",
                        v=data.names,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="Birth date",
                        c="OK" if bool(data.born) else "N/A",
                        v=data.born,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="Sex",
                        c="OK" if bool(data.sex) else "N/A",
                        v=data.sex,
                    ),
                    "  Reset",
                ]
                + (["  Continue"] if valid else []),
            )

            if do == 0:
                name = await self._io.prompt("Given name")
                data.given_name = name
                data.names.append(name)
            elif do == 1:
                data.family_name = await self._io.prompt("Family name")
            elif do == 2:
                data.names.append(await self._io.prompt("One (1) middle name"))
            elif do == 3:
                data.born = await self._io.prompt(
                    "Birth date (YYYY-MM-DD)", t=datetime.date.fromisoformat
                )
            elif do == 4:
                data.sex = await self._io.choose(
                    "Biological sex", ["man", "woman", "undefined"]
                )
            elif do == 5:
                data = PersonData()
                data.given_name = None
                data.family_name = None
                data.names = []
                data.born = None
                data.sex = None
            elif do == 6:
                break

            if all(data._asdict()) and data.given_name in data.names:
                valid = True
            else:
                valid = False

        return data

    async def do_ministry(self):
        """Collect ministry entity data."""
        self._io << (
            "It is necessary to collect information "
            + "for the ministry entity.\n"
        )
        valid = False
        data = MinistryData()
        data.vision = None
        data.ministry = None
        data.founded = None

        while True:
            do = await self._io.menu(
                "Ministry entity data, (* = mandatory)",
                [
                    "{m} {t:17} {c:4} {v}".format(
                        m=" ",
                        t="Vision",
                        c="OK" if bool(data.vision) else "N/A",
                        v=data.vision,
                    ),
                    "{m} {t:17} {c:4} {v}".format(
                        m="*",
                        t="Ministry name",
                        c="OK" if bool(data.ministry) else "N/A",
                        v=data.ministry,
                    ),
                    "{m} {t:17} {c:4} {v}".format(
                        m="*",
                        t="Ministry founded",
                        c="OK" if bool(data.founded) else "N/A",
                        v=data.founded,
                    ),
                    "  Reset",
                ]
                + (["  Continue"] if valid else []),
            )

            if do == 0:
                vision = await self._io.prompt("Ministry vision")
                data.vision = vision
            elif do == 1:
                data.ministry = await self._io.prompt("Ministry name")
            elif do == 2:
                data.founded = await self._io.prompt(
                    "Ministry founded (YYYY-MM-DD)",
                    t=datetime.date.fromisoformat,
                )
            elif do == 3:
                data = MinistryData()
                data.vision = None
                data.ministry = None
                data.founded = None
            elif do == 4:
                break

            if all(data._asdict()):
                valid = True
            else:
                valid = False

        return data

    async def do_church(self):
        """Collect church entity data."""
        self._io << (
            "It is necessary to collect information for the church entity.\n"
        )
        valid = False
        data = ChurchData()
        data.founded = None
        data.city = None
        data.region = None
        data.country = None

        while True:
            do = await self._io.menu(
                "Church entity data, (* = mandatory)",
                [
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="Founded",
                        c="OK" if bool(data.founded) else "N/A",
                        v=data.founded,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="City",
                        c="OK" if bool(data.city) else "N/A",
                        v=data.city,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m=" ",
                        t="Region/state",
                        c="OK" if bool(data.region) else "N/A",
                        v=data.region,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m=" ",
                        t="Country/nation",
                        c="OK" if bool(data.country) else "N/A",
                        v=data.country,
                    ),
                    "  Reset",
                ]
                + (["  Continue"] if valid else []),
            )

            if do == 0:
                founded = await self._io.prompt(
                    "Church founded when (YYYY-MM-DD)",
                    t=datetime.date.fromisoformat,
                )
                data.founded = founded
            elif do == 1:
                data.city = await self._io.prompt("Church of what city")
            elif do == 2:
                data.region = await self._io.prompt(
                    "Region or state (if applicable)"
                )
            elif do == 3:
                data.country = await self._io.prompt("Country ")
            elif do == 4:
                data = ChurchData()
                data.founded = None
                data.city = None
                data.region = None
                data.country = None
            elif do == 5:
                break

            if all(data._asdict()):
                valid = True
            else:
                valid = False

        return data

    async def do_import(self):
        """Import entity from seed vault."""
        self._io << "importing entities not implemented."

    async def _switch(self):
        await asyncio.sleep(2)
        self._ioc.state("serving", True)
        await asyncio.sleep(2)
        self._ioc.state("nodes", True)
        await asyncio.sleep(2)
        self._ioc.state("hosts", True)
        await asyncio.sleep(2)
        self._ioc.state("clients", True)

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs["io"], kwargs["ioc"].env["dir"].root, kwargs["ioc"])


class StartupCommand(Command):
    """Unlock and start the server."""

    abbr = """Unlock and start."""
    description = (
        """Receive the master key, then unlock and start the server."""
    )  # noqa E501

    def __init__(self, io, root, ioc):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "startup", io)
        self._root = root
        self._ioc = ioc

    async def _command(self, opts):
        try:
            if isinstance(self._ioc.facade, Facade):
                self._io << "\nServer already running.\n\n"
            else:
                key = await self._io.secret("Enter the master key")
                secret = binascii.unhexlify(key.encode())

                facade = await Facade.open(self._root, secret)
                self._ioc.facade = facade
                self._io << "\nSuccessfully loaded the facade.\nID: %s\n\n" % (
                    facade.data.portfolio.entity.id
                )

            self._io << (
                "You just de-encrypted and loaded the Facade. Next step in\n"
                + "boot sequence is to start the services and the Admin console.\n"  # noqa E501
                + "Meanwhile you will be logged out from the Boot console.\n"  # noqa E501
            )
            await self._io.presskey()
            asyncio.ensure_future(self._switch())
            raise Util.exception(Error.CMD_SHELL_EXIT)

        except (ValueError, binascii.Error) as e:
            logging.exception("Error: %s" % e)
            self._io << "\nError: %s\n\n" % e

    async def _switch(self):
        await asyncio.sleep(2)
        self._ioc.state("serving", True)
        await asyncio.sleep(2)
        self._ioc.state("nodes", True)
        await asyncio.sleep(2)
        self._ioc.state("hosts", True)
        await asyncio.sleep(2)
        self._ioc.state("clients", True)

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs["io"], kwargs["ioc"].env["dir"].root, kwargs["ioc"])


class EnvCommand(Command):
    """Work with environment variables."""

    abbr = """Work with environment valriables."""
    description = (
        """Use this command to display the environment variables."""
    )  # noqa E501

    def __init__(self, io, env):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "env", io)
        self.__env = env

    async def _command(self, opts):
        self._io << ("\nEnvironment variables:\n" + "-" * 79 + "\n")
        self._io << "\n".join(self._recurse(self.__env))
        self._io << "\n" + "-" * 79 + "\n\n"

    def _recurse(self, obj, suf="", level=0):
        items = []
        for k, v in obj.items():
            if isinstance(v, BaseAuto):
                items += self._recurse(vars(v), k, level + 1)
            else:
                items.append(
                    "{s:}{k:}: {v:}".format(
                        s=(suf + "." if suf else ""), k=k, v=v
                    )
                )
        return items

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs["io"], kwargs["ioc"].env)


class QuitCommand(Command):
    """Shutdown the angelos server."""

    abbr = """Shutdown the angelos server"""
    description = """Use this command to shutdown the angelos server from the terminal."""  # noqa E501

    def __init__(self, io, state):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "quit", io)
        self._state = state

    def _rules(self):
        return {"depends": ["yes"]}

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return [
            Option(
                "yes",
                abbr="y",
                type=Option.TYPE_BOOL,
                help="Confirm that you want to shutdown server",
            )
        ]

    async def _command(self, opts):
        if opts["yes"]:
            self._io << (
                "\nStarting shutdown sequence for the Angelos server.\n\n"
            )
            self._state("all", False)
            asyncio.ensure_future(self._quit())
            for t in ["3", ".", ".", "2", ".", ".", "1", ".", ".", "0"]:
                self._io << t
                time.sleep(0.333)
            raise Util.exception(Error.CMD_SHELL_EXIT)
        else:
            self._io << (
                "\nYou didn't confirm shutdown sequence. Use --yes/-y.\n\n"
            )

    async def _quit(self):
        await asyncio.sleep(5)
        os.kill(os.getpid(), signal.SIGINT)

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs["io"], kwargs["ioc"].state)
