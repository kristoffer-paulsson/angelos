# cython: language_level=3
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
import asyncio
import binascii
import datetime
import logging
import os

from angelos.cmd import Command
from libangelos.const import Const
from libangelos.document.entities import Person, Church, Ministry
from libangelos.document.entity_mixin import PersonMixin, MinistryMixin, ChurchMixin
from libangelos.error import Error, ModelException
from libangelos.facade.facade import Facade
from libangelos.library.nacl import SecretBox
from libangelos.misc import Misc
from libangelos.operation.setup import SetupPersonOperation, SetupMinistryOperation, SetupChurchOperation, PersonData, \
    MinistryData, ChurchData
from libangelos.utils import Util


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
        self._root = str(root)
        self._ioc = ioc

    async def _command(self, opts):
        """Do entity setup."""
        try:
            if isinstance(self._ioc.facade, Facade):
                self._io << "\nServer already running.\n\n"
                return

            vault_file = Util.path(str(self._ioc.env["state_dir"]), Const.CNL_VAULT)
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

                ip = await self.do_ip()

                # Generate master key
                secret = SecretBox().sk
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
                    self._io << "\n\nMaster key mismatch.\n\n"
                    return
                    # raise RuntimeError("Master key mismatch")

                os.makedirs(self._root, exist_ok=True)
                if subdo == 0:
                    portfolio = SetupPersonOperation.create(entity_data, server=True, ip=ip)
                    facade = await Facade.setup(self._root, secret, role, True, portfolio=portfolio)
                elif subdo == 1:
                    portfolio = SetupMinistryOperation.create(entity_data, server=True, ip=ip)
                    facade = await Facade.setup(self._root, secret, role, True, portfolio=portfolio)
                elif subdo == 2:
                    portfolio = SetupChurchOperation.create(entity_data, server=True, ip=ip)
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
            self._io << ("\n")
            print(e)
            logging.error("Error: %s" % e, exc_info=True)
        else:
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

    def _validate_person(self, entity: Person) -> bool:
        try:
            for name in PersonMixin._fields.keys():
                entity._fields[name].validate(getattr(entity, name), name)
            PersonMixin._check_names(entity)
        except ModelException:
            return False
        else:
            return True

    async def do_person(self):
        """Collect person entity data."""
        self._io << (
            "It is necessary to collect information for the person entity.\n"
        )
        valid = False
        entity = Person()

        while True:
            do = await self._io.menu(
                "Person entity data, (* = mandatory)",
                [
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="First name",
                        c="OK" if bool(entity.given_name) else "N/A",
                        v=entity.given_name,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="Family name",
                        c="OK" if bool(entity.family_name) else "N/A",
                        v=entity.family_name,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="Middle names",
                        c="OK" if bool(entity.names) else "N/A",
                        v=entity.names,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="Birth date",
                        c="OK" if bool(entity.born) else "N/A",
                        v=entity.born,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="Sex",
                        c="OK" if bool(entity.sex) else "N/A",
                        v=entity.sex,
                    ),
                    "  Reset",
                ]
                + (["  Continue"] if valid else []),
            )

            if do == 0:
                name = await self._io.prompt("Given name")
                entity.given_name = name
                names = [name]
                entity.names = entity.names + names if entity.names else names
            elif do == 1:
                entity.family_name = await self._io.prompt("Family name")
            elif do == 2:
                names = [await self._io.prompt("One (1) middle name")]
                entity.names = entity.names + names if entity.names else names
            elif do == 3:
                entity.born = await self._io.prompt(
                    "Birth date (YYYY-MM-DD)", t=datetime.date.fromisoformat
                )
            elif do == 4:
                entity.sex = await self._io.choose(
                    "Biological sex", ["man", "woman", "undefined"]
                )
            elif do == 5:
                entity = Person()
            elif do == 6:
                break

            valid = self._validate_person(entity)

        entity_data = PersonData(
            given_name=entity.given_name,
            names=entity.names,
            family_name=entity.family_name,
            sex=entity.sex,
            born=entity.born
        )

        return entity_data

    def _validate_ministry(self, entity) -> bool:
        try:
            for name in MinistryMixin._fields.keys():
                entity._fields[name].validate(getattr(entity, name), name)
        except ModelException:
            return False
        else:
            return True

    async def do_ministry(self):
        """Collect ministry entity data."""
        self._io << (
            "It is necessary to collect information "
            + "for the ministry entity.\n"
        )
        valid = False
        entity = Ministry()

        while True:
            do = await self._io.menu(
                "Ministry entity data, (* = mandatory)",
                [
                    "{m} {t:17} {c:4} {v}".format(
                        m=" ",
                        t="Vision",
                        c="OK" if bool(entity.vision) else "N/A",
                        v=entity.vision,
                    ),
                    "{m} {t:17} {c:4} {v}".format(
                        m="*",
                        t="Ministry name",
                        c="OK" if bool(entity.ministry) else "N/A",
                        v=entity.ministry,
                    ),
                    "{m} {t:17} {c:4} {v}".format(
                        m="*",
                        t="Ministry founded",
                        c="OK" if bool(entity.founded) else "N/A",
                        v=entity.founded,
                    ),
                    "  Reset",
                ]
                + (["  Continue"] if valid else []),
            )

            if do == 0:
                vision = await self._io.prompt("Ministry vision")
                entity.vision = vision
            elif do == 1:
                entity.ministry = await self._io.prompt("Ministry name")
            elif do == 2:
                entity.founded = await self._io.prompt(
                    "Ministry founded (YYYY-MM-DD)",
                    t=datetime.date.fromisoformat,
                )
            elif do == 3:
                entity = Ministry()
            elif do == 4:
                break

            valid = self._validate_ministry(entity)

        entity_data = MinistryData(
            ministry=entity.ministry,
            vision=entity.vision,
            founded=entity.founded
        )

        return entity_data

    def _validate_church(self, entity) -> bool:
        try:
            for name in ChurchMixin._fields.keys():
                entity._fields[name].validate(getattr(entity, name), name)
        except ModelException:
            return False
        else:
            return True

    async def do_church(self):
        """Collect church entity data."""
        self._io << (
            "It is necessary to collect information for the church entity.\n"
        )
        valid = False
        entity = Church()

        while True:
            do = await self._io.menu(
                "Church entity data, (* = mandatory)",
                [
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="Founded",
                        c="OK" if bool(entity.founded) else "N/A",
                        v=entity.founded,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m="*",
                        t="City",
                        c="OK" if bool(entity.city) else "N/A",
                        v=entity.city,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m=" ",
                        t="Region/state",
                        c="OK" if bool(entity.region) else "N/A",
                        v=entity.region,
                    ),
                    "{m} {t:15} {c:4} {v}".format(
                        m=" ",
                        t="Country/nation",
                        c="OK" if bool(entity.country) else "N/A",
                        v=entity.country,
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
                entity.founded = founded
            elif do == 1:
                entity.city = await self._io.prompt("Church of what city")
            elif do == 2:
                entity.region = await self._io.prompt(
                    "Region or state (if applicable)"
                )
            elif do == 3:
                entity.country = await self._io.prompt("Country ")
            elif do == 4:
                entity = Church()
            elif do == 5:
                break

            valid = self._validate_church(entity)

        entity_data = ChurchData(
            city=entity.city,
            founded=entity.founded,
            region=entity.region,
            country=entity.country
        )

        return entity_data

    async def do_ip(self):
        """Choose a public IP-address"""
        ips = Misc.ip()

        while True:
            do = await self._io.menu(
                "Chose public IP-address",
                [" {i:16}".format(i=str(ip)) for ip in ips]
            )

            if do < len(ips):
                confirmation = await self._io.confirm("Use %s as public IP-address." % ips[do])
                if confirmation is True:
                    break
                else:
                    continue
            else:
                self._io << ("Choice out of range.\n")

        return ips[do]

    async def do_import(self):
        """Import entity from seed vault."""
        self._io << "importing entities not implemented."

    async def _switch(self):
        # await asyncio.sleep(2)
        self._ioc.state("serving", True)
        # await asyncio.sleep(2)
        self._ioc.state("nodes", True)
        # await asyncio.sleep(2)
        self._ioc.state("hosts", True)
        # await asyncio.sleep(2)
        self._ioc.state("clients", True)

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs["io"], str(kwargs["ioc"].env["state_dir"]), kwargs["ioc"])