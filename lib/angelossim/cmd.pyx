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
"""Dummy data generation utilities for server commands."""
import uuid

from libangelos.dummy.support import generate_filename, generate_data
from libangelos.policy.message import MessagePolicy, EnvelopePolicy
from libangelos.policy.portfolio import PGroup, DOCUMENT_PATTERN
from libangelos.document.document import DocType

from libangelos.const import Const
from .cmd import Command, Option


class DummyCommand(Command):
    """Populate server with dummy data."""

    abbr = """Generate dummy data on the server."""
    description = """Generate sets of dummy data for testing."""  # noqa E501
    msg_start = """
Dummy command lets you generate sets of dummy information for testing on the
server.
"""

    def __init__(self, io, ioc):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "dummy", io)
        self._ioc = ioc

    async def _command(self, opts):
        """Do entity setup."""
        if opts["mail"]:
            eid = uuid.UUID("urn:uuid:" + str(opts["mail"]))
            entity = await self._ioc.facade.load_portfolio(
                eid, PGroup.VERIFIER
            )
            mail = self._ioc.facade.archive(Const.CNL_MAIL)
            if not mail:
                self._io << "No transit mailbox found. Fail!"
                return

            for i in range(5):
                msg = EnvelopePolicy.wrap(
                    self._ioc.facade.portfolio,
                    entity,
                    MessagePolicy.mail(self._ioc.facade.portfolio, entity)
                    .message(
                        generate_filename(postfix="."),
                        generate_data().decode(),
                    )
                    .done(),
                )

                filename = str(msg.id) + DOCUMENT_PATTERN[DocType.COM_ENVELOPE]
                self._io << (
                    "Generating random mail (%s) to %s\n"
                    % (filename, str(eid))
                )
                await mail.save("/" + filename, msg)

    def _rules(self):
        return {"exclusive": ["mail"], "option": ["mail"]}

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return [
            Option(
                "mail",
                abbr="m",
                type=Option.TYPE_VALUE,
                help="Send messages to a user",
            )
        ]

    @classmethod
    def factory(cls, **kwargs):
        """Create command with env from IoC."""
        return cls(kwargs["io"], kwargs["ioc"])
