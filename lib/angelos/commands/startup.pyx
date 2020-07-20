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
import logging

from angelos.cmd import Command
from libangelos.error import Error
from libangelos.facade.facade import Facade
from libangelos.utils import Util


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