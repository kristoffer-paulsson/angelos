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
"""Implementation of intermediary transport and the standard noise protocol for Angelos."""
import asyncio
import logging
import os
from asyncio import CancelledError
from asyncio.protocols import Protocol
from asyncio.transports import Transport
from typing import Any, Union, Callable

from angelos.bin.nacl import PublicKey, SecretKey, Backend_25519_ChaChaPoly_BLAKE2b


# TODO: Certify that this implementation of Noise_XX_25519_ChaChaPoly_BLAKE2b
#  is interoperable with other implementations.


class HandshakeError(RuntimeWarning):
    """The handshake failed."""
    pass


class NonceDepleted(RuntimeWarning):
    """The nonce is depleted and connection must be terminated."""


class CipherState:
    """State of the cipher algorithm."""

    def __init__(self):
        self.k = None
        self.n = None


class SymmetricState:
    """The symmetric state of the protocol."""

    def __init__(self):
        self.h = None
        self.ck = None
        self.cipher_state = None


class HandshakeState:
    """The handshake state."""

    def __init__(self):
        self.symmetric_state = None
        self.s = None
        self.e = None
        self.rs = None
        self.re = None


class NoiseProtocol(Backend_25519_ChaChaPoly_BLAKE2b):
    """Static implementation of Noise Protocol Noise_XX_25519_ChaChaPoly_BLAKE2b."""

    MAX_MESSAGE_LEN = 2 ** 16 - 1
    MAX_NONCE = 2 ** 64 - 1

    __slots__ = (
        "_name", "_initiator", "_handshake_hash", "_handshake_state", "_symmetric_state", "_cipher_state_handshake",
        "_cipher_state_encrypt", "_cipher_state_decrypt", "_static_key"
    )

    def __init__(self, initiator: bool, static_key: SecretKey):
        Backend_25519_ChaChaPoly_BLAKE2b.__init__(self, 64, 64)
        self._name = b"Noise_XX_25519_ChaChaPoly_BLAKE2b"
        self._initiator = initiator
        self._handshake_hash = None
        self._handshake_state = None
        self._symmetric_state = None
        self._cipher_state_handshake = None
        self._cipher_state_encrypt = None
        self._cipher_state_decrypt = None
        self._static_key = static_key

    @property
    def protocol(self) -> bytes:
        return self._name

    @property
    def handshake_hash(self) -> bytes:
        return self._handshake_hash

    def _initialize_key(self, cs: CipherState, key):
        """Reset a cipher state with a new key."""
        cs.k = key
        cs.n = 0

    def _encrypt_with_ad(self, cs: CipherState, ad: bytes, plaintext: bytes) -> bytes:
        """Encrypt a message with additional data."""
        if cs.n == self.MAX_NONCE:
            raise NonceDepleted()

        if cs.k is None:
            return plaintext

        ciphertext = self._encrypt(cs.k, cs.n.to_bytes(8, "little"), plaintext, ad)
        cs.n += 1
        return ciphertext

    def _decrypt_with_ad(self, cs: CipherState, ad: bytes, ciphertext: bytes) -> bytes:
        """Decrypt cipher using additional data."""
        if cs.n == self.MAX_NONCE:
            raise NonceDepleted()

        if cs.k is None:
            return ciphertext

        plaintext = self._decrypt(cs.k, cs.n.to_bytes(8, "little"), ciphertext, ad)
        cs.n += 1
        return plaintext

    def _mix_key(self, ss: SymmetricState, input_key_material: bytes):
        """Mix key with data"""
        ss.ck, temp_k = self._hkdf2(ss.ck, input_key_material)
        if self.hashlen == 64:
            temp_k = temp_k[:32]

        self._initialize_key(ss.cipher_state, temp_k)

    def _mix_hash(self, ss: SymmetricState, data: bytes):
        """Mix hash with data."""
        ss.h = self._hash(ss.h + data)

    def _encrypt_and_hash(self, ss: SymmetricState, plaintext: bytes) -> bytes:
        """Encrypt a message, then mix the hash with the cipher."""
        ciphertext = self._encrypt_with_ad(ss.cipher_state, ss.h, plaintext)
        self._mix_hash(ss, ciphertext)
        return ciphertext

    def _decrypt_and_hash(self, ss: SymmetricState, ciphertext: bytes) -> bytes:
        """Decrypt a message, then hash with the cipher"""
        plaintext = self._decrypt_with_ad(ss.cipher_state, ss.h, ciphertext)
        self._mix_hash(ss, ciphertext)
        return plaintext

    async def _initiator_xx(self, writer: Callable, reader: Callable):
        """Shake hand as initiator according to XX."""

        # Step 1
        # WRITE True e
        buffer = bytearray()
        self._handshake_state.e = self._generate() if self._handshake_state.e is None else self._handshake_state.e
        buffer += self._handshake_state.e.pk
        self._mix_hash(self._handshake_state.symmetric_state, self._handshake_state.e.pk)
        buffer += self._encrypt_and_hash(self._handshake_state.symmetric_state, b"")
        writer(buffer)

        # Step 2
        message = await reader()
        # READ True e
        self._handshake_state.re = PublicKey(bytes(message[:self.dhlen]))
        message = message[self.dhlen:]
        self._mix_hash(self._handshake_state.symmetric_state, self._handshake_state.re.pk)
        # READ True ee
        self._mix_key(self._handshake_state.symmetric_state,
                      self._dh(self._handshake_state.e.sk, self._handshake_state.re.pk))
        # READ True s
        if self._cipher_state_handshake.k is not None:
            temp = bytes(message[:self.dhlen + 16])
            message = message[self.dhlen + 16:]
        else:
            temp = bytes(message[:self.dhlen])
            message = message[self.dhlen:]
        self._handshake_state.rs = PublicKey(self._decrypt_and_hash(self._handshake_state.symmetric_state, temp))
        # READ True es
        self._mix_key(self._handshake_state.symmetric_state,
                      self._dh(self._handshake_state.e.sk, self._handshake_state.rs.pk))
        if self._decrypt_and_hash(self._handshake_state.symmetric_state, bytes(message)) != b"":
            raise HandshakeError()

        # Step 3
        # WRITE True s
        buffer = bytearray()
        buffer += self._encrypt_and_hash(self._handshake_state.symmetric_state, self._handshake_state.s.pk)
        # WRITE True se
        self._mix_key(self._handshake_state.symmetric_state,
                      self._dh(self._handshake_state.s.sk, self._handshake_state.re.pk))
        buffer += self._encrypt_and_hash(self._handshake_state.symmetric_state, b"")
        writer(buffer)

    async def _responder_xx(self, writer: Callable, reader: Callable):
        """Shake hand as responder according to XX."""
        message = await reader()
        # READ False e
        self._handshake_state.re = PublicKey(bytes(message[:self.dhlen]))
        message = message[self.dhlen:]
        self._mix_hash(self._handshake_state.symmetric_state, self._handshake_state.re.pk)
        if self._decrypt_and_hash(self._handshake_state.symmetric_state, bytes(message)) != b"":
            raise HandshakeError()

        buffer = bytearray()
        # WRITE False e
        self._handshake_state.e = self._generate() if self._handshake_state.e is None else self._handshake_state.e
        buffer += self._handshake_state.e.pk
        self._mix_hash(self._handshake_state.symmetric_state, self._handshake_state.e.pk)
        # WRITE False ee
        self._mix_key(self._handshake_state.symmetric_state,
                      self._dh(self._handshake_state.e.sk, self._handshake_state.re.pk))
        # WRITE False s
        buffer += self._encrypt_and_hash(self._handshake_state.symmetric_state, self._handshake_state.s.pk)
        # WRITE False es
        self._mix_key(self._handshake_state.symmetric_state,
                      self._dh(self._handshake_state.s.sk, self._handshake_state.re.pk))
        buffer += self._encrypt_and_hash(self._handshake_state.symmetric_state, b"")
        writer(buffer)

        message = await reader()
        buffer = bytearray()
        # READ False s
        if self._cipher_state_handshake.k is not None:
            temp = bytes(message[:self.dhlen + 16])
            message = message[self.dhlen + 16:]
        else:
            temp = bytes(message[:self.dhlen])
            message = message[self.dhlen:]
        self._handshake_state.rs = PublicKey(self._decrypt_and_hash(self._handshake_state.symmetric_state, temp))
        # READ False se
        self._mix_key(self._handshake_state.symmetric_state,
                      self._dh(self._handshake_state.e.sk, self._handshake_state.rs.pk))
        if self._decrypt_and_hash(self._handshake_state.symmetric_state, bytes(message)) != b"":
            raise HandshakeError()

    async def start_handshake(self, writer: Callable, reader: Callable):
        """Do noise protocol handshake."""
        ss = SymmetricState()
        if len(self._name) <= self.hashlen:
            ss.h = self._name.ljust(self.hashlen, b"\0")
        else:
            ss.h = self._hash(self._name)

        ss.ck = ss.h

        ss.cipher_state = CipherState()
        self._initialize_key(ss.cipher_state, None)
        self._cipher_state_handshake = ss.cipher_state

        hs = HandshakeState()
        hs.symmetric_state = ss
        self._mix_hash(hs.symmetric_state, b"")  # Empty prologue

        hs.s = self._static_key

        self._handshake_state = hs
        self._symmetric_state = self._handshake_state.symmetric_state

        if self._initiator:
            await self._initiator_xx(writer, reader)
        else:
            await self._responder_xx(writer, reader)

        temp_k1, temp_k2 = self._hkdf2(self._handshake_state.symmetric_state.ck, b"")

        if self.hashlen == 64:
            temp_k1 = temp_k1[:32]
            temp_k2 = temp_k2[:32]

        c1, c2 = CipherState(), CipherState()
        self._initialize_key(c1, temp_k1)
        self._initialize_key(c2, temp_k2)
        if self._initiator:
            self._cipher_state_encrypt = c1
            self._cipher_state_decrypt = c2
        else:
            self._cipher_state_encrypt = c2
            self._cipher_state_decrypt = c1

        self._handshake_hash = self._symmetric_state.h

        self._handshake_state = None
        self._symmetric_state = None
        self._cipher_state_handshake = None

    def encrypt(self, data: bytes) -> bytes:
        """Encrypt data into a cipher before writing."""
        if len(data) > self.MAX_MESSAGE_LEN:
            raise ValueError("Data must be less or equal to {}.".format(self.MAX_MESSAGE_LEN))
        return self._encrypt_with_ad(self._cipher_state_encrypt, None, data)

    def decrypt(self, data: bytes) -> bytes:
        """Decrypt a cipher into data before reading."""
        if len(data) > self.MAX_MESSAGE_LEN:
            raise ValueError("Data must be less or equal to {}".format(self.MAX_MESSAGE_LEN))
        return self._decrypt_with_ad(self._cipher_state_decrypt, None, data)


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
            self._transport.close()

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
        done before forwarded to the overlaying protocol."""
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

        if self._task_conn:
            self._task_conn.cancel()
        if self._task_close:
            self._task_close.cancel()

    def pause_writing(self) -> None:
        """Passthroughs to overlying protocol."""
        self._protocol.pause_writing()

    def resume_writing(self) -> None:
        """Passthroughs to overlying protocol."""
        self._protocol.resume_writing()

    def data_received(self, data: Union[bytes, bytearray, memoryview]) -> None:
        """Reads data to the protocol generally with flow interruption depending on mode.
        DIVERT will interrupt and cancel flow to overlying protocol.
        PASSTHROUGH will first transform flow and then pass on to overlying protocol.
        EAVESDROP will first transform flow, then pass to overlying protocol and lastly interrupt flow."""
        if self._mode is not self.DIVERT:
            data = self._on_received(data)
            self._protocol.data_received(data)

        if self._mode is not self.PASSTHROUGH:
            self._read.set_result(data)

    def eof_received(self) -> bool:
        """Eof is interrupted and can be managed before forwarding to overlaying protocol."""
        self._on_eof()
        return self._protocol.eof_received()


class NoiseTransportProtocol(IntermediateTransportProtocol):
    __slots__ = ("_noise", "_server")

    def __init__(self, protocol: Protocol, server: bool = False, key: bytes = None):
        IntermediateTransportProtocol.__init__(self, protocol)
        self._noise = NoiseProtocol(not server, SecretKey(os.urandom(32)))
        self._event = asyncio.Event()
        self._event.set()
        self._server = server

    async def _on_connection(self):
        """Perform noise protocol handshake before telling application protocol connection_made()."""
        try:
            self._set_mode(IntermediateTransportProtocol.DIVERT)
            await self._noise.start_handshake(self._transport.write, self._reader)
            self._set_mode(IntermediateTransportProtocol.PASSTHROUGH)
        except CancelledError:
            pass

    # async def _on_close(self) -> None:
    #    """Clean up protocol."""
    #    self._protocol.close()

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
