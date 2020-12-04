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
"""Authentication handler."""
from angelos.net.base import PacketHandler


class MailError(RuntimeError):
    """Unrepairable errors in the mail handler."""
    pass


class MailHandler(PacketHandler):
    """Base handler for mail."""

    LEVEL = 1
    RANGE = 1

    PKT_STUB = 0

    PACKETS = {
        PKT_STUB: None
    }

    PROCESS = dict()


class MailClient(MailHandler):
    """Client side mail handler."""

    PROCESS = {
        MailHandler.PKT_STUB: None
    }

    def __init__(self, manager: "PacketManager"):
        super().__init__(manager)

    def start(self, node: bool = False):
        """Make authentication against server."""


class MailServer(MailHandler):
    """Server side mail handler."""

    PROCESS = {
        MailHandler.PKT_STUB: None
    }

    def __init__(self, manager: "PacketManager"):
        super().__init__(manager)
