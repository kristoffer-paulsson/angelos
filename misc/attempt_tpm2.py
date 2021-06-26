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
"""Trusted platform module interaction set according to TPM 2.0."""
import os
from pathlib import PosixPath
from struct import Struct


class StructureTags:
    """TPM2 Structure Tags."""
    NULL = 0x8000
    NO_SESSIONS = 0x8001
    SESSIONS = 0x8002


class CommandCodes:
    """TPM2 Command Codes"""
    GET_RANDOM = 0x0000017B


class BaseTPM2Device:
    pass


class BaseTPM2Operation:
    pass


if os.name == "posix":

    class TPM2Device(BaseTPM2Device):
        """Representation of current TPM device or interface."""

        PATH = PosixPath("/dev/tpm0")
        PACKER = Struct("!HII")

        def __init__(self):
            self._fd = os.open(self.PATH, os.O_RDWR)

        def __del__(self):
            if getattr(self, "_fd", None):
                os.close(self._fd)

        def write(self, session: bool, command_code: int, data: bytes = bytes()):
            """Write information to the TPM."""
            command_size = len(data) + self.PACKER.size
            payload = self.PACKER.pack(
                StructureTags.SESSIONS if session else StructureTags.NO_SESSIONS, command_size, command_code) + data

            if 1024 < len(payload) < 10:
                raise ValueError("Size of payload to large or small.")

            if os.write(self._fd, payload) != len(payload):
                raise OSError("Error at TPM module, failed writing.")

            response = os.read(self._fd, 4096)

            if len(response) < 10:
                raise OSError("Failed retrieving result from TPM module.")

            return self.PACKER.unpack_from(response) + (response[10:],)


elif os.name == "nt":

    pass


class TPM2Session:
    """TPM2 Session context manager."""
    def __init__(self):
        self._device = None

    def __enter__(self) -> BaseTPM2Device:
        self._device = TPM2Device()
        return self._device

    def __exit__(self, exc_type, exc_val, exc_tb):
        del self._device


class TestOperation(BaseTPM2Operation):

    def __init__(self):
        pass

    def get_random(self, bytes_requested: int):
        device = TPM2Device()
        tag, response_size, response_code, random_bytes = device.write(
            False, CommandCodes.GET_RANDOM, int(bytes_requested).to_bytes(2, "big", signed=False))

        print("TAG", tag)
        print("RESPONSE SIZE", response_size)
        print("RESPONSE CODE", response_code)
        print("RANDOM BYTES", random_bytes)


if __name__ == "__main__":
    TestOperation().get_random(100)
