# cython: language_level=3
#
# Copyright (c) 2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""Implementation of several but not all protocols within the Noise Protocol Framework."""
import asyncio
import itertools
import os
from asyncio.protocols import Protocol
from asyncio.transports import Transport
from typing import Any, Union
from noise.connection import NoiseConnection, Keypair

# And he made in Jerusalem engines, invented by cunning men, to be on
# the towers and upon the bulwarks, to shoot arrows and great stones
# withal. And his name spread far abroad; for he was marvellously
# helped, till he was strong. (2 Chronicles 26:15 KJV)


class IntermediateTransportProtocol(Transport, Protocol):
    """Intermediate layer in between a native transport and a program protocol,
    for manipulating I/O such as encryption."""

    DIVERT = 1
    PASSTHROUGH = 2
    EAVESDROP = 3

    __slots__ = ("_loop", "_mode", "_protocol", "_transport", "_task_conn", "_task_close", "_read", "_write")

    def __init__(self, protocol: Protocol):
        Transport.__init__(self)
        Protocol.__init__(self)

        self._loop = asyncio.get_running_loop()
        self._protocol = protocol
        self._transport = None

        self._task_conn = None
        self._task_close = None

        self._mode = None
        self._read = None
        self._write = None
        self._set_mode(self.PASSTHROUGH)

    async def _on_connection(self) -> None:
        """Connection made handler, overwrite to use."""
        pass

    async def _on_close(self) -> None:
        """Close handler, overwrite to use."""
        pass

    def _on_write(self, data: Union[bytes, bytearray, memoryview]) -> Union[bytes, bytearray, memoryview]:
        """Process written data before handed to the native transport. Overwrite to use."""
        return data

    def _on_received(self, data: Union[bytes, bytearray, memoryview]) -> Union[bytes, bytearray, memoryview]:
        """Process received data before handed to the application protocol. Overwrite to use."""
        return data

    def _on_lost(self) -> None:
        """Lost connection handler, overwrite to use."""
        pass

    def _on_eof(self) -> None:
        """"Received eof handler, overwrite to use."""
        pass

    async def _reader(self):
        """Receives a copy of the data from the underlying native transport in DIVERT and EAVESDROP mode.
        This method should be awaited when in use for interrupting flow.
        Use self._transport.write() to respond."""
        data = await self._read
        self._read.__init__(loop=self._read.get_loop())
        return data

    async def _writer(self):
        """Receives a copy of the data from the overlying application protocol in DIVERT and EAVESDROP mode.
        This method should be awaited when in use for interrupting flow.
        Use self._protocol.received_data() to respond."""
        data = await self._write
        self._write.__init__(loop=self._write.get_loop())
        return data

    def _set_mode(self, mode: int):
        """Set any of the modes DIVERT, PASSTHROUGH, EAVESDROP and configure futures."""
        self._mode = mode
        if mode is self.PASSTHROUGH:
            self._read = None
            self._write = None
        else:
            self._read = self._read if self._read else self._loop.create_future()
            self._write = self._write if self._write else self._loop.create_future()

    ## Methods bellow belongs to the Transport part.

    def get_extra_info(self, name: str, default: Any = None) -> Any:
        """Passthroughs to underlying transport."""
        return self._transport.get_extra_info(name, default)

    def is_closing(self) -> bool:
        """Passthroughs to underlying transport."""
        return self._transport.is_closing() or self._task_close

    def close(self) -> None:
        """Close from application protocol with flow interruption."""
        if self._task_close:
            return

        def done(fut):
            fut.result()
            self._transport.close(self)

        self._task_close = asyncio.create_task(self._on_close())
        self._task_close.add_done_callback(done)

    def set_protocol(self, protocol: Protocol) -> None:
        """Passthroughs to underlying transport."""
        self._protocol = protocol

    def get_protocol(self) -> Protocol:
        """Passthroughs to underlying transport."""
        return self._protocol

    def is_reading(self) -> bool:
        """Passthroughs to underlying transport."""
        return self._transport.is_reading()

    def pause_reading(self) -> None:
        """Passthroughs to underlying transport."""
        self._transport.pause_reading()

    def resume_reading(self) -> None:
        """Passthroughs to underlying transport."""
        self._transport.resume_reading()

    def set_write_buffer_limits(self, high: int = None, low: int = None) -> None:
        """Passthroughs to underlying transport."""
        self._transport.set_write_buffer_limits(high, low)

    def get_write_buffer_size(self) -> int:
        """Passthroughs to underlying transport."""
        return self._transport.get_write_buffer_size()

    def write(self, data: Union[bytes, bytearray, memoryview]) -> None:
        """Writes data to the transport generally with flow interruption depending on mode.
        DIVERT will interrupt and cancel flow to underlying transport.
        PASSTHROUGH will first transform flow and then pass on to underlying transport.
        EAVESDROP will first interrupt flow, then transform and lastly pass to underlying transport.
        """
        if self._mode is not self.PASSTHROUGH:
            self._write.set_result(data)
        if self._mode is not self.DIVERT:
            data = self._on_write(data)
            self._transport.write(data)

    def write_eof(self) -> None:
        """Passthroughs to underlying transport."""
        self._transport.write_eof()

    def can_write_eof(self) -> bool:
        """Passthroughs to underlying transport."""
        return self._transport.can_write_eof()

    def abort(self) -> None:
        """Passthroughs to underlying transport."""
        self._transport.abort()

    ## Methods bellow belongs to the Protocol part.

    def connection_made(self, transport: Transport) -> None:
        """Connection made on underlying transport. Flow is interrupted and operations can be
        done before forwarded to teh overlaying protocol."""
        self._transport = transport
        if self._task_conn:
            raise BlockingIOError("Can only run one connection made at a time.")

        def done(fut):
            fut.result()
            self._protocol.connection_made(self)
            self._task_conn = None

        self._task_conn = asyncio.create_task(self._on_connection())
        self._task_conn.add_done_callback(done)

    def connection_lost(self, exc: Exception) -> None:
        """Connection loss is interrupted and can be managed before forwarding to overlaying protocol."""
        self._on_lost()
        self._protocol.connection_lost(exc)

    def pause_writing(self) -> None:
        """Passthroughs to overlying protocol."""
        self._protocol.pause_writing()

    def resume_writing(self) -> None:
        """Passthroughs to overlying protocol."""
        self._protocol.resume_writing()

    def data_received(self, data: Union[bytes, bytearray, memoryview]) -> None:
        """Reades data to the protocol generally with flow interruption depending on mode.
        DIVERT will interrupt and cancel flow to overlying protocol.
        PASSTHROUGH will first transform flow and then pass on to overlying protocol.
        EAVESDROP will first transform flow, then pass to overlying protocoll and lastly interrupt flow."""
        if self._mode is not self.DIVERT:
            data = self._on_received(data)
            self._protocol.data_received(data)
        if self._mode is not self.PASSTHROUGH:
            self._read.set_result(data)

    def eof_received(self) -> None:
        """Eof is interrupted and can be managed before forwarding to overlaying protocol."""
        self._on_eof()
        self._protocol.eof_recieved()


class NoiseTransportProtocol(IntermediateTransportProtocol):
    __slots__ = ("_noise", "_server")

    def __init__(self, protocol: Protocol, server: bool = False, key: bytes = None):
        IntermediateTransportProtocol.__init__(self, protocol)
        self._noise = NoiseConnection.from_name(b"Noise_XX_25519_ChaChaPoly_BLAKE2b")
        self._event = asyncio.Event()
        self._event.set()
        if server:
            self._noise.set_as_responder()
        else:
            self._noise.set_as_initiator()
        self._noise.set_keypair_from_private_bytes(Keypair.STATIC, key if key else os.urandom(32))
        self._server = server

    async def _on_connection(self) -> None:
        """Perform noise protocol handshake before telling application protocol connection_made()."""
        side = "Server" if self._server else "Client"
        self._set_mode(IntermediateTransportProtocol.DIVERT)
        # print("{0} HANDSHAKE Start".format(side))
        self._noise.start_handshake()

        cycle = ["receive", "send"]
        for action in itertools.cycle(cycle if self._server else reversed(cycle)):
            if self._noise.handshake_finished:
                break
            elif action == "send":
                send = self._noise.write_message()
                # print("{0} {1} {2} {3}".format(side, action.upper(), len(send), send))
                self._transport.write(send)
            elif action == "receive":
                receive = await self._reader()
                # print("{0} {1} {2} {3}".format(side, action.upper(), len(receive), receive))
                self._noise.read_message(receive)

        self._set_mode(IntermediateTransportProtocol.PASSTHROUGH)
        # print("{0} HANDSHAKE Over".format(side))

    def _on_write(self, data: Union[bytes, bytearray, memoryview]) -> Union[bytes, bytearray, memoryview]:
        """Encrypt outgoing data with Noise."""
        cipher = self._noise.encrypt(data)
        self._event.clear()
        return cipher

    def _on_received(self, cipher: Union[bytes, bytearray, memoryview]) -> Union[bytes, bytearray, memoryview]:
        """Decrypt incoming data with Noise."""
        data = self._noise.decrypt(cipher)
        self._event.set()
        return data

    async def wait(self):
        await self._event.wait()
