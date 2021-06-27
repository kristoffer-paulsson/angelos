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


class StartupType:
    """TPM2 Startup Type."""
    CLEAR = 0x0000
    STATE = 0x0001


class CommandCodes:
    """TPM2 Command Codes."""
    STARTUP = 0x00000144
    SHUTDOWN = 0x00000145
    GET_RANDOM = 0x0000017B


class ResponseCodes:
    """TPM2 Response Codes."""
    SUCCESS = 0x000
    BAD_TAG = 0x01E
    VER1 = 0x100
    INITIALIZE = VER1 + 0x000
    FAILURE = VER1 + 0x001
    SEQUENCE = VER1 + 0x003
    PRIVATE = VER1 + 0x00B
    HMAC = VER1 + 0x019
    DISABLED = VER1 + 0x020
    EXCLUSIVE = VER1 + 0x021
    AUTH_TYPE = VER1 + 0x024
    AUTH_MISSING = VER1 + 0x025
    POLICY = VER1 + 0x026
    PCR = VER1 + 0x027
    PCR_CHANGED = VER1 + 0x028
    UPGRADE = VER1 + 0x02D
    TOO_MANY_CONTEXTS = VER1 + 0x02E
    UNAVAILABLE = VER1 + 0x02F
    REBOOT = VER1 + 0x030
    UNBALANCED = VER1 + 0x031
    COMMAND_SIZE = VER1 + 0x042
    COMMAND_CODE = VER1 + 0x043
    AUTHSIZE = VER1 + 0x044
    AUTH_CONTEXT = VER1 + 0x045
    NV_RANGE = VER1 + 0x046
    NV_SIZE = VER1 + 0x047
    NV_LOCKED = VER1 + 0x048
    NV_AUTHORIZATION = VER1 + 0x049
    NV_UNINITIALIZED = VER1 + 0x04A
    NV_SPACE = VER1 + 0x04B
    NV_DEFINED = VER1 + 0x04C
    BAD_CONTEXT = VER1 + 0x050
    CPHASH = VER1 + 0x051
    PARENT = VER1 + 0x052
    NEEDS_TEST = VER1 + 0x053
    NO_RESULT = VER1 + 0x054
    SENSITIVE = VER1 + 0x055
    MAX_FM0 = VER1 + 0x07F
    FMT1 = 0x080
    WARN = 0x900


RESPONSE_CODES = dict((v, k) for k, v in vars(ResponseCodes).items())


class StructureTags:
    """TPM2 Structure Tags."""
    NULL = 0x8000
    NO_SESSIONS = 0x8001
    SESSIONS = 0x8002


STRUCTURE_TAGS = dict((v, k) for k, v in vars(StructureTags).items())


class BaseTPM2Device:
    """Base TPM module class."""

    def _write(self, payload: bytes) -> bytes:
        raise NotImplementedError()

    def send(self, session: bool, command_code: int, data: bytes = bytes()):
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
        tag, response_size, response_code, response_data = self.PACKER.unpack_from(response) + (response[10:],)
        if len(response) != response_size:
            raise OSError("Retrieved data size inconsistent.")

        return tag, response_code, response_data

    def validate(self, tag: int, response_code: int):
        """Validate a response."""
        if tag not in STRUCTURE_TAGS.keys():
            raise ValueError("Unknown Structure Tag: {}".format(tag))

        if response_code == ResponseCodes.SUCCESS:
            return
        elif response_code in RESPONSE_CODES.keys():
            error = "TPM2 Call failed with response code: {}, {}".format(response_code, RESPONSE_CODES[response_code])
        else:
            error = "Unknown response code: {}".format(response_code)

        raise TypeError(error)


class BaseTPM2Operation:
    """Base TPM module operations class"""

    def startup(self, startup_type: int):
        device = TPM2Device()
        tag, response_code, _ = device.send(
            False, CommandCodes.STARTUP, int(startup_type).to_bytes(2, "big", signed=False))
        device.validate(tag, response_code)

    def shutdown(self, shutdown_type: int):
        device = TPM2Device()
        tag, response_code, _ = device.send(
            False, CommandCodes.SHUTDOWN, int(shutdown_type).to_bytes(2, "big", signed=False))
        device.validate(tag, response_code)


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

        def _write(self, payload: bytes) -> bytes:
            if os.write(self._fd, payload) != len(payload):
                raise OSError("Error at TPM module, failed writing.")
            return os.read(self._fd, 4096)


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

    def reset(self):
        print("SHUTDOWN")
        self.shutdown(StartupType.CLEAR)
        print("STARTUP")
        self.startup(StartupType.CLEAR)

    def get_random(self, bytes_requested: int):
        device = TPM2Device()
        tag, response_code, random_bytes = device.send(
            False, CommandCodes.GET_RANDOM, int(bytes_requested).to_bytes(2, "big", signed=False))

        device.validate(tag, response_code)
        self._print(tag, response_code)
        print("RANDOM BYTES", random_bytes)

    def _print(self, tag, response_code):
        print("TAG", tag)
        print("RESPONSE CODE", response_code)


if __name__ == "__main__":
    TestOperation().reset()
