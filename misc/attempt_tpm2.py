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
import time
from pathlib import PosixPath
from struct import Struct
from typing import Tuple


class Capabilities:
    """TPM2 Capability selectors."""
    FIRST = 0x00000000
    ALGS = 0x00000000
    HANDLES = 0x00000001
    COMMANDS = 0x00000002
    PP_COMMANDS = 0x00000003
    AUDIT_COMMANDS = 0x00000004
    PCRS = 0x00000005
    TPM_PROPERTIES = 0x00000006
    PCR_PROPERTIES = 0x00000007
    ECC_CURVES = 0x00000008
    AUTH_POLICIES = 0x00000009
    LAST = 0x00000009
    VENDOR_PROPERTY = 0x00000100


class StartupType:
    """TPM2 Startup Type."""
    CLEAR = 0x0000
    STATE = 0x0001


class CommandCodes:
    """TPM2 Command Codes."""
    FIRST = 0x0000011F
    EVICT_CONTROL = 0x00000120
    CLEAR = 0x00000126
    SET_PRIMARY_POLICY = 0x0000012E
    STARTUP = 0x00000144
    SHUTDOWN = 0x00000145
    LOAD = 0x00000157
    LOAD_EXTERNAL = 0x00000167
    VERIFY_SIGNATURE = 0x00000177
    GET_CAPABILITY = 0x0000017A
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
    INSUFFICIENT = FMT1 + 0x01A
    WARN = 0x900


RESPONSE_CODES = dict((v, k) for k, v in vars(ResponseCodes).items())


class PermanentHandles:  # TPM_RH_*
    """TPM Permanent Handles."""
    OWNER = 0x40000001
    NULL = 0x40000007
    LOCKOUT = 0x4000000A
    ENDORSEMENT = 0x4000000B
    PLATFORM = 0x4000000C


class StructureTags:
    """TPM2 Structure Tags."""
    NULL = 0x8000
    NO_SESSIONS = 0x8001
    SESSIONS = 0x8002
    VERIFIED = 0x8022


STRUCTURE_TAGS = dict((v, k) for k, v in vars(StructureTags).items())


class AlgorithmConstants:
    """TPM2 Algorithm constants."""
    SHA256 = 0x000B  # Digest
    NULL = 0x0010  # Null
    ECDSA = 0x0018


class TPM2Object:
    """TPM object. TPMA_OBJECT"""

    def __init__(self, fixed_tpm: bool, st_clear: bool, fixed_parent: bool, sensitive_data_origin: bool,
                 user_with_auth: bool, admin_with_policy: bool, no_da: bool, encrypted_duplication: bool,
                 restricted: bool, decrypt: bool, sign_encrypt: bool):
        self._fixed_tpm = fixed_tpm
        self._st_clear = st_clear
        self._fixed_parent = fixed_parent
        self._sensitive_data_origin = sensitive_data_origin
        self._user_with_auth = user_with_auth
        self._admin_with_policy = admin_with_policy
        self._no_da = no_da
        self._encrypted_duplication = encrypted_duplication
        self._restricted = restricted
        self._decrypt = decrypt
        self._sign_encrypt = sign_encrypt

    def __bytes__(self):
        return int(int(self._fixed_tpm) << 1 + int(self._st_clear) << 2 + int(self._fixed_parent) << 4 + int(
            self._sensitive_data_origin) << 5 + int(self._user_with_auth) << 6 + int(
            self._admin_with_policy) << 7 + int(self._no_da) << 10 + int(self._encrypted_duplication) << 11 + int(
            self._restricted) << 16 + int(self._decrypt) << 17 + int(self._sign_encrypt) << 18).to_bytes(
            4, "big", signed=False)


class TPM2Public:
    """TPM public structure. TPMT_PUBLIC"""  # TPMU_PUBLIC_PARMS, TPMU_PUBLIC_ID
    # TPMS_KEYEDHASH_PARMS, TPMS_SYMCIPHER_PARMS, TPMS_RSA_PARMS, TPMS_ECC_PARMS, TPMS_ASYM_PARMS

    def __init__(self, type: int, name_alg, object_attributes: bytes, auth_policy: bytes, parameters, unique):
        self._type = type
        self._name_alg = name_alg
        self._object_attributes = object_attributes
        self._auth_policy = auth_policy

    def __bytes__(self):
        return int(self._type).to_bytes(2, "big", signed=False) + \
               int(self._name_alg).to_bytes(2, "big", signed=False) + \
               self._object_attributes + int(len(self._auth_policy)).to_bytes(
            2, "big", signed=False) + self._auth_policy + \


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

    def get_random(self, bytes_requested: int) -> bytes:
        device = TPM2Device()
        tag, response_code, random_bytes = device.send(
            False, CommandCodes.GET_RANDOM, int(bytes_requested).to_bytes(2, "big", signed=False))

        device.validate(tag, response_code)
        return random_bytes

    def set_primary_policy(
            self, auth_handle: int, auth_policy: bytes = b"\x00\x00", hash_alg: int = AlgorithmConstants.NULL):
        """Set primary policy."""
        device = TPM2Device()
        tag, response_code, _ = device.send(
            False, CommandCodes.SET_PRIMARY_POLICY,
            int(auth_handle).to_bytes(4, "big", signed=False) +
            int(len(auth_policy)).to_bytes(2, "big", signed=False) + auth_policy +
            int(hash_alg).to_bytes(2, "big", signed=False)
        )

        device.validate(tag, response_code)

    def verify_signature(self, key_handle: int, digest: bytes, signature: bytes) -> bool:
        device = TPM2Device()
        tag, response_code, validation = device.send(
            False, CommandCodes.VERIFY_SIGNATURE,
            int(key_handle).to_bytes(4, "big", signed=False) +
            int(len(digest)).to_bytes(2, "big", signed=False) + digest +
            int(len(signature)).to_bytes(2, "big", signed=False) + signature
        )
        device.validate(tag, response_code)
        return True if validation[:2] == int(StructureTags.VERIFIED).to_bytes(2, "big", signed=False) else False

    def load(self, session: bool, parent_handle: int, in_private: bytes, in_public: bytes) -> Tuple[bytes, bytes]:
        device = TPM2Device()
        tag, response_code, result = device.send(
            session, CommandCodes.LOAD,
            int(parent_handle).to_bytes(4, "big", signed=False) +
            int(len(in_private)).to_bytes(2, "big", signed=False) + in_private +
            int(len(in_public)).to_bytes(2, "big", signed=False) + in_public
        )
        device.validate(tag, response_code)
        object_handle = result[:4]
        length = int.from_bytes(result[4:6], "big", signed=False)
        name = result[6:]
        if len(name) != length:
            raise ValueError("Object handle invalid length.")
        return object_handle, name

    def load_external(self, session: bool, in_private: bytes, in_public: bytes, hierarchy: int) -> Tuple[bytes, bytes]:
        device = TPM2Device()
        if in_private is None:
            in_private = b"\x00\x00"
        tag, response_code, result = device.send(
            session, CommandCodes.LOAD_EXTERNAL,
            # int(len(in_private)).to_bytes(2, "big", signed=False) + in_private +
            int(len(in_public)).to_bytes(2, "big", signed=False) + in_public +
            int(hierarchy).to_bytes(4, "big", signed=False)
        )
        device.validate(tag, response_code)
        object_handle = result[:4]
        length = int.from_bytes(result[4:6], "big", signed=False)
        name = result[6:]
        if len(name) != length:
            raise ValueError("Object handle invalid length.")
        return object_handle, name

    def evict_control(self, platform: bool, object_handle: int, persistent_handle: int):
        device = TPM2Device()
        tag, response_code, _ = device.send(
            True, CommandCodes.EVICT_CONTROL,
            int(PermanentHandles.PLATFORM if platform else PermanentHandles.OWNER).to_bytes(4, "big", signed=False) +
            int(object_handle).to_bytes(4, "big", signed=False) +
            int(persistent_handle).to_bytes(4, "big", signed=False)
        )
        device.validate(tag, response_code)

    # EK create and persist

    # SRK create and persist


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

    def provision(self):
        blob = self.get_random(20)

    def _print(self, tag, response_code):
        print("TAG", tag)
        print("RESPONSE CODE", response_code)

    def clear(self, auth_handle: int):
        device = TPM2Device()
        tag, response_code, _ = device.send(
            True, CommandCodes.CLEAR, int(auth_handle).to_bytes(4, "big", signed=False))
        device.validate(tag, response_code)

    def get_capabilities(self, session: bool, capability: int, property: int, property_count: int) -> Tuple[
        bool, bytes]:
        device = TPM2Device()
        tag, response_code, data = device.send(
            session, CommandCodes.GET_CAPABILITY,
            int(capability).to_bytes(4, "big", signed=False) +
            int(property).to_bytes(4, "big", signed=False) +
            int(property_count).to_bytes(4, "big", signed=False)
        )
        device.validate(tag, response_code)
        more_data = bool(data[:1])
        capability_data = data[1:]
        return more_data, capability_data
        print("MORE_DATA", more_data)
        print("CAPABILITY_DATA", capability_data)


class PhysicalPresence:
    """Physical Presence Interface scanner."""

    PATH = PosixPath("/sys/class/tpm/tpm0/ppi/")

    PP_REQUIRED_FOR_TURN_ON = 1
    PP_REQUIRED_FOR_TURN_OFF = 2
    PP_REQUIRED_FOR_CLEAR = 3
    PP_REQUIRED_FOR_CHANGE_PCRS = 4
    PP_REQUIRED_FOR_CHANGE_EPS = 5
    PP_REQUIRED_FOR_ENABLE_BLOCKSIDFUNC = 6
    PP_REQUIRED_FOR_DISABLE_BLOCKSIDFUNC = 7

    def __init__(self):
        with self.PATH.joinpath("version").open("r") as fd:
            self._version = fd.read().strip()
        with self.PATH.joinpath("tcg_operations").open("r") as fd:
            self._tcg_operations = fd.read()
        with self.PATH.joinpath("vs_operations").open("r") as fd:
            self._vs_operations = fd.read()

        self._request_fd = self.PATH.joinpath("request").open("w+")
        self._response_fd = self.PATH.joinpath("response").open("r")
        self._transition_action = self.PATH.joinpath("transition_action").open("r")

        if self._version != "1.3":
            raise OSError("Illegal PPI version, must be 1.3 but is: {}".format(self._version))

    @property
    def version(self) -> str:
        """TPM PPI version."""
        return self._version

    @property
    def transition(self) -> str:
        """Current transition action."""
        return self._transition_action.read().strip()

    @property
    def tcg(self):
        """TCG operations."""
        return self._tcg_operations

    @property
    def vs(self):
        "VS operations."
        return self._vs_operations

    def __del__(self):
        self._request_fd.close()
        self._response_fd.close()
        self._transition_action.close()

    def _request(self, command: str):
        self._request_fd.write("{}\n".format(command))

    def _response(self) -> str:
        return self._response_fd.read()

    def _operation(self, cmd: str) -> str:
        self._request(cmd)
        time.sleep(2)
        return self._response()

    def enable(self):
        return self._operation("1")

    def disable(self):
        return self._operation("2")

    def clear(self):
        return self._operation("5")

    def enable_clear(self):
        return self._operation("14")

    def true_set_pp_required_for_clear(self):
        return self._operation("17")

    def false_set_pp_required_for_clear(self):
        return self._operation("18")

    def enable_clear2(self):
        return self._operation("21")

    def enable_clear3(self):
        return self._operation("22")

    def set_pcr_banks(self):
        return self._operation("23")

    def change_eps(self):
        return self._operation("24")

    def false_set_pp_required_for_change_pcrs(self):
        return self._operation("25")

    def true_set_pp_required_for_change_pcrs(self):
        return self._operation("26")

    def false_set_pp_required_for_turn_on(self):
        return self._operation("27")

    def true_set_pp_required_for_turn_on(self):
        return self._operation("28")

    def false_set_pp_required_for_turn_off(self):
        return self._operation("29")

    def true_set_pp_required_for_turn_off(self):
        return self._operation("30")

    def false_set_pp_required_for_change_eps(self):
        return self._operation("31")

    def true_set_pp_required_for_change_eps(self):
        return self._operation("32")

    def log_all_digests(self):
        return self._operation("33")

    def disable_endorsment_enable_storage_hierarchy(self):
        return self._operation("34")

    def enable_blocksidfunc(self):
        return self._operation("96")

    def disable_blocksidfunc(self):
        return self._operation("97")

    def true_set_pp_required_for_enable_blocksidfunc(self):
        return self._operation("98")

    def false_set_pp_required_for_enable_blocksidfunc(self):
        return self._operation("99")

    def true_set_pp_required_for_disable_blocksidfunc(self):
        return self._operation("100")

    def false_set_pp_required_for_disable_blocksidfunc(self):
        return self._operation("101")


if __name__ == "__main__":
    # TestOperation().get_capabilities(False, Capabilities.COMMANDS, CommandCodes.FIRST, 1024)
    public = TPM2Public(
        AlgorithmConstants.ECDSA, AlgorithmConstants.NULL,
        TPM2Object(False, False, False, False, False, False, False, False, True, False, False),
        b"\x00\x00",
    )
    to = TestOperation()
    handle, name = to.load_external(False, None, os.urandom(32), PermanentHandles.NULL)
    to.evict_control(True, None, handle)
    # pp = PhysicalPresence()
    # # print(pp.true_set_pp_required_for_clear())
    # print(pp.clear())
    # print(pp.version)
    # print(pp.tcg)
    # print(pp.vs)
    # print(TestOperation().reset())
