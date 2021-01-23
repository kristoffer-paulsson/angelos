# cython: language_level=3
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
import asyncio

from angelos.common.misc import AsyncCallable
from angelos.net.base import Handler, ConfirmCode, ClientStateExchangeMachine, ServerStateExchangeMachine


class ServiceBoundariesError(RuntimeWarning):
    """Service range out of bounds."""


class ServiceBrokerHandler(Handler):

    LEVEL = 1
    RANGE = 2

    ST_VERSION = 0x01
    ST_SERVICE = 0x02

    def __init__(self, manager: "Protocol"):
        Handler.__init__(self, manager, {
            self.ST_VERSION: b"broker-0.1",
            self.ST_SERVICE: b"",
        }, dict(), 0)


class ServiceBrokerClient(ServiceBrokerHandler):

    def __init__(self, manager: "Protocol"):
        ServiceBrokerHandler.__init__(self, manager)

    async def request(self, service: int) -> bool:
        """Request a network service by range."""
        if not 1 <= service <= 512:
            raise ServiceBoundariesError()

        self._states[self.ST_SERVICE] = service.to_bytes(2, "big", signed=False)
        result = await self._tell_state(self.ST_SERVICE) == ConfirmCode.YES
        asyncio.get_running_loop().call_soon(self._reset_state)  # Reset soon
        return result

    def _reset_state(self):
        ClientStateExchangeMachine.__init__(self._state_machines[self.ST_SERVICE])


class ServiceBrokerServer(ServiceBrokerHandler):

    def __init__(self, manager: "Protocol"):
        ServiceBrokerHandler.__init__(self, manager)
        self.__acb = AsyncCallable(self._check_service)
        self._state_machines[self.ST_SERVICE].check = self.__acb

    async def _check_service(self, value: bytes) -> int:
        """Check handler availability based on range."""
        range = int.from_bytes(value[:2], "big", signed=False)
        result = ConfirmCode.YES if self._manager.get_handler(range) else ConfirmCode.NO_COMMENT
        asyncio.get_running_loop().call_soon(self._reset_state)  # Reset soon
        return result

    def _reset_state(self):
        ServerStateExchangeMachine.__init__(self._state_machines[self.ST_SERVICE], self.__acb)
