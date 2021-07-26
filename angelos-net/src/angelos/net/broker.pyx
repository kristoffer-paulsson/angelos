#
# Copyright (c) 2018-2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""Service broker handler."""

from angelos.common.misc import SyncCallable
from angelos.net.base import Handler, ConfirmCode, StateMode, ProtocolNegotiationError, NetworkSession

BROKER_VERSION = b"broker-0.1"


class ServiceBoundariesError(RuntimeWarning):
    """Service range out of bounds."""


class ServiceBrokerHandler(Handler):
    LEVEL = 1
    RANGE = 2

    ST_VERSION = 0x01
    ST_SERVICE = 0x02

    def __init__(self, manager: "Protocol"):
        Handler.__init__(self, manager, states={
            self.ST_VERSION: (StateMode.MEDIATE, BROKER_VERSION),
            self.ST_SERVICE: (StateMode.REPRISE, b""),
        })


class ServiceBrokerClient(ServiceBrokerHandler):

    def __init__(self, manager: "Protocol"):
        ServiceBrokerHandler.__init__(self, manager)

    async def request(self, service: int) -> bool:
        """Request a network service by range."""
        await self._manager.ready()
        if not 1 <= service <= 512:
            raise ServiceBoundariesError()

        if not self._states[self.ST_VERSION].frozen:
            version = await self._call_mediate(self.ST_VERSION, [BROKER_VERSION])
            if version is None:
                raise ProtocolNegotiationError()

        self._states[self.ST_SERVICE].update(service.to_bytes(2, "big", signed=False))
        return await self._call_tell(self.ST_SERVICE) is not None


class ServiceBrokerServer(ServiceBrokerHandler):

    def __init__(self, manager: "Protocol"):
        ServiceBrokerHandler.__init__(self, manager)
        self._states[self.ST_VERSION].upgrade(SyncCallable(self._negotiate_version))
        self._states[self.ST_SERVICE].upgrade(SyncCallable(self._check_service))

    def _negotiate_version(self, value: bytes, sesh: NetworkSession = None) -> int:
        """Negotiate protocol version."""
        return ConfirmCode.YES if value == BROKER_VERSION else ConfirmCode.NO

    def _check_service(self, value: bytes, sesh: NetworkSession = None) -> int:
        """Check handler availability based on range."""
        range = int.from_bytes(value[:2], "big", signed=False)
        result = ConfirmCode.YES if self._manager.get_handler(range) else ConfirmCode.NO_COMMENT
        return result
