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
import binascii
import ipaddress
import itertools
import os
import socket
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
    NV_UNDEFINE_SPACE_SPECIAL = 0x0000011F
    EVICT_CONTROL = 0x00000120
    HIERARCHY_CONTROL = 0x00000121
    NV_UNDEFINE_SPACE = 0x00000122
    CHANGE_EPS = 0x00000124
    CHANGE_PPS = 0x00000125
    CLEAR = 0x00000126
    CLEAR_CONTROL = 0x00000127
    CLOCK_SET = 0x00000128
    HIERARCHY_CHANGE_AUTH = 0x00000129
    NV_DEFINE_SPACE = 0x0000012A
    PCR_ALLOCATE = 0x0000012B
    PCR_SET_AUTH_POLICY = 0x0000012C
    PP_COMMANDS = 0x0000012D
    SET_PRIMARY_POLICY = 0x0000012E
    FIELD_UPGRADE_START = 0x0000012F
    CLOCK_RATE_ADJUST = 0x00000130
    CREATE_PRIMARY = 0x00000131
    NV_GLOBAL_WRITE_LOCK = 0x00000132
    GET_COMMAND_AUDIT_DIGEST = 0x00000133
    NV_INCREMENT = 0x00000134
    NV_SET_BITS = 0x00000135
    NV_EXTEND = 0x00000136
    NV_WRITE = 0x00000137
    NV_WRITE_LOCK = 0x00000138
    DICTIONARY_ATTACK_LOCK_RESET = 0x00000139
    DICTIONARY_ATTACK_PARAMETERS = 0x0000013A
    NV_CHANGE_AUTH = 0x0000013B
    PCR_EVENT = 0x0000013C
    PCR_RESET = 0x0000013D
    SEQUENCE_COMPLETE = 0x0000013E
    SET_ALGORITHM_SET = 0x0000013
    SET_COMMAND_CODE_AUDIT_STATUS = 0x00000140
    FIELD_UPGRADE_DATA = 0x00000141
    INCREMENTAL_SELF_TEST = 0x00000142
    SELF_TEST = 0x00000143
    STARTUP = 0x00000144
    SHUTDOWN = 0x00000145
    STIR_RANDOM = 0x00000146
    ACTIVATE_CREDENTIAL = 0x00000147
    CERTIFY = 0x00000148
    POLICY_NV = 0x00000149
    CERTIFY_CREATION = 0x0000014A
    DUPLICATE = 0x0000014B
    GET_TIME = 0x0000014C
    GET_SESSION_AUDIT_DIGEST = 0x0000014D
    NV_READ = 0x0000014E
    NV_READ_LOCK = 0x0000014F
    OBJECT_CHANGE_AUTH = 0x00000150
    POLICY_SECRET = 0x00000151
    REWRAP = 0x00000152
    CREATE = 0x00000153
    ECDH_ZGEN = 0x00000154
    HMAC = 0x00000155
    IMPORT = 0x00000156
    LOAD = 0x00000157
    QUOTE = 0x00000158
    RSA_DECRYPT = 0x00000159
    HMAC_START = 0x0000015B
    SEQUENCE_UPDATE = 0x0000015C
    SIGN = 0x0000015D
    UNSEAL = 0x0000015E
    POLICY_SIGNED = 0x00000160
    CONTEXT_LOAD = 0x00000161
    CONTEXT_SAVE = 0x00000162
    ECDH_KEY_GEN = 0x00000163
    ENCRYPT_DECRYPT = 0x00000164
    FLUSH_CONTEXT = 0x00000165
    LOAD_EXTERNAL = 0x00000167
    MAKE_CREDENTIAL = 0x00000168
    NV_READ_PUBLIC = 0x00000169
    POLICY_AUTHORIZE = 0x0000016A
    POLICY_AUTH_VALUE = 0x0000016B
    POLICY_COMMAND_CODE = 0x0000016C
    POLICY_COUNTER_TIMER = 0x0000016D
    POLICY_CP_HASH = 0x0000016E
    POLICY_LOCALITY = 0x0000016F
    POLICY_NAME_HASH = 0x00000170
    POLICY_OR = 0x00000171
    POLICY_TICKET = 0x00000172
    READ_PUBLIC = 0x00000173
    RSA_ENCRYPT = 0x00000174
    START_AUTH_SESSION = 0x00000176
    VERIFY_SIGNATURE = 0x00000177
    ECC_PARAMETERS = 0x00000178
    FIRMWARE_READ = 0x00000179
    GET_CAPABILITY = 0x0000017A
    GET_RANDOM = 0x0000017B
    GET_TEST_RESULT = 0x0000017C
    HASH = 0x0000017D
    PCR_READ = 0x0000017E
    POLICY_PCR = 0x0000017F
    POLICY_RESTART = 0x00000180
    READ_CLOCK = 0x00000181
    PCR_EXTEND = 0x00000182
    PCR_SET_AUTH_VALUE = 0x00000183
    NV_CERTIFY = 0x00000184
    EVENT_SEQUENCE_COMPLETE = 0x00000185
    HASH_SEQUENCE_START = 0x00000186
    POLICY_PHYSICAL_PRESENCE = 0x00000187
    POLICY_DUPLICATION_SELECT = 0x00000188
    POLICY_GET_DIGEST = 0x00000189
    TEST_PARAMS = 0x0000018A
    COMMIT = 0x0000018B
    POLICY_PASSWORD = 0x0000018C
    ZGEN_2PHASE = 0x0000018D
    EC_EPHEMERAL = 0x0000018E
    POLICY_NV_WRITTEN = 0x0000018F
    POLICY_TEMPLATE = 0x00000190
    CREATE_LOADED = 0x00000191
    POLICY_AUTHORIZE_NV = 0x00000192
    ENCRYPT_DECRYPT_2 = 0x00000193


COMMAND_CODES = dict((v, k) for k, v in vars(CommandCodes).items())


class ResponseCodes:
    """TPM2 Response Codes."""
    SUCCESS = 0x000
    BAD_TAG = 0x01E

    VER1 = 0x100
    class ver1:
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

    RC_VER1 = dict((v, k) for k, v in vars(ver1).items())

    FMT1 = 0x080
    class fmt1:
        FMT1 = 0x080
        ASYMMETRIC = FMT1 + 0x001
        ATTRIBUTES = FMT1 + 0x002
        HASH = FMT1 + 0x003
        VALUE = FMT1 + 0x004
        HIERARCHY = FMT1 + 0x005
        KEY_SIZE = FMT1 + 0x007
        MGF = FMT1 + 0x008
        MODE = FMT1 + 0x009
        TYPE = FMT1 + 0x00A
        HANDLE = FMT1 + 0x00B
        KDF = FMT1 + 0x00C
        RANGE = FMT1 + 0x00D
        AUTH_FAIL = FMT1 + 0x00E
        NONCE = FMT1 + 0x00F
        PP = FMT1 + 0x010
        SCHEME = FMT1 + 0x012
        SIZE = FMT1 + 0x015
        SYMMETRIC = FMT1 + 0x016
        TAG = FMT1 + 0x017
        SELECTOR = FMT1 + 0x018
        INSUFFICIENT = FMT1 + 0x01A
        SIGNATURE = FMT1 + 0x01B
        KEY = FMT1 + 0x01C
        POLICY_FAIL = FMT1 + 0x01D
        INTEGRITY = FMT1 + 0x01F
        TICKET = FMT1 + 0x020
        RESERVED_BITS = FMT1 + 0x021
        BAD_AUTH = FMT1 + 0x022
        EXPIRED = FMT1 + 0x023
        POLICY_CC = FMT1 + 0x024
        BINDING = FMT1 + 0x025
        CURVE = FMT1 + 0x026
        ECC_POINT = FMT1 + 0x027

    RC_FMT1 = dict((v, k) for k, v in vars(fmt1).items())

    WARN = 0x900
    class warn:
        WARN = 0x900
        CONTEXT_GAP = WARN + 0x001
        OBJECT_MEMORY = WARN + 0x002
        SESSION_MEMORY = WARN + 0x003
        MEMORY = WARN + 0x004
        SESSION_HANDLES = WARN + 0x005
        OBJECT_HANDLES = WARN + 0x006
        LOCALITY = WARN + 0x007
        YIELDED = WARN + 0x008
        CANCELED = WARN + 0x009
        TESTING = WARN + 0x00A
        REFERENCE_H0 = WARN + 0x010
        REFERENCE_H1 = WARN + 0x011
        REFERENCE_H2 = WARN + 0x012
        REFERENCE_H3 = WARN + 0x013
        REFERENCE_H4 = WARN + 0x014
        REFERENCE_H5 = WARN + 0x015
        REFERENCE_H6 = WARN + 0x016
        REFERENCE_S0 = WARN + 0x018
        REFERENCE_S1 = WARN + 0x019
        REFERENCE_S2 = WARN + 0x01A
        REFERENCE_S3 = WARN + 0x01B
        REFERENCE_S4 = WARN + 0x01C
        REFERENCE_S5 = WARN + 0x01D
        REFERENCE_S6 = WARN + 0x01E
        NV_RATE = WARN + 0x020
        LOCKOUT = WARN + 0x021
        RETRY = WARN + 0x022
        NV_UNAVAILABLE = WARN + 0x023
        NOT_USED = WARN + 0x7F

    RC_WARN = dict((v, k) for k, v in vars(warn).items())


# RESPONSE_CODES = dict((v, k) for k, v in vars(ResponseCodes).items())


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
    RSA = 0x0001
    SHA1 = 0x0004
    HMAC = 0x0005
    AES = 0x0006
    MGF1 = 0x0007
    KEYEDHASH = 0x0008
    XOR = 0x000A
    SHA256 = 0x000B  # Digest
    SHA384 = 0x000C
    SHA512 = 0x000D
    NULL = 0x0010  # Null
    SM3_256 = 0x0012
    SM4 = 0x0013
    RSASSA = 0x0014
    RSAES = 0x0015
    RSAPSS = 0x0016
    OAEP = 0x0017
    ECDSA = 0x0018
    ECDH = 0x0019
    ECDAA = 0x001A
    SM2 = 0x001B
    ECSCHNORR = 0x001C
    ECMQV = 0x001D
    KDF1_SP800_56A = 0x0020
    KDF2 = 0x0021
    KDF1_SP800_108 = 0x0022
    ECC = 0x0023
    SYMCIPHER = 0x0025
    CAMELLIA = 0x0026
    CTR = 0x0040
    OFB = 0x0041
    CBC = 0x0042
    CFB = 0x0043
    ECB = 0x0044


ALGORITHM_CONSTANTS = dict((v, k) for k, v in vars(AlgorithmConstants).items())


class EccCurve:
    """TPM2 Ecc curves."""
    NIST_P192 = 0x0001
    NIST_P224 = 0x0002
    NIST_P256 = 0x0003
    NIST_P384 = 0x0004
    NIST_P521 = 0x0005
    BN_P256 = 0x0010
    BN_P638 = 0x0011
    SM2_P256 = 0x0020


ECC_CURVE = dict((v, k) for k, v in vars(EccCurve).items())


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

    """
    TPMU_PUBLIC_PARMS
        eccDetail: TPMS_ECC_PARMS
            symmetric: TPMT_SYM_DEF_OBJECT+
                +TPMI_ALG_SYM_OBJECT
                TPMU_SYM_KEY_BITS
                TPMU_SYM_MODE
                TPMU_SYM_DETAILS
            scheme: TPMT_ECC_SCHEME+
                +TPMI_ALG_ECC_SCHEME
                TPMU_ASYM_SCHEME
            curveID: TPMI_ECC_CURVE
            kdf: TPMT_KDF_SCHEME+
                +TPMI_ALG_KDF
                TPMU_KDF_SCHEME
        asymDetail: TPMS_ASYM_PARMS
            symmetric: TPMT_SYM_DEF_OBJECT+
            scheme: TPMT_ASYM_SCHEME+
    """

    def __init__(self, type: int, name_alg: int, object_attributes: bytes, auth_policy: bytes, parameters: bytes,
                 unique):
        self._type = type
        self._name_alg = name_alg
        self._object_attributes = object_attributes
        self._auth_policy = auth_policy
        self._parameters = parameters
        self._unique = unique

    def __bytes__(self):
        return int(self._type).to_bytes(2, "big", signed=False) + \
               int(self._name_alg).to_bytes(2, "big", signed=False) + \
               self._object_attributes + self._auth_policy + self._parameters + self._unique


"""
TPM2B_SENSITIVE
    size:           UINT16
    sensitiveArea:  TPMT_SENSITIVE
        sensitiveType:              TPMI_ALG_PUBLIC
            TPM_ALG_!ALG.o
            #TPM_RC_TYPE
        authValue:                  TPM2B_AUTH
            TPM2B_DIGEST
                size:                           UINT16
                buffer[size]{:sizeof(TPMU_HA)}: BYTE
        seedValue:                  TPM2B_DIGEST
            size:                           UINT16
            buffer[size]{:sizeof(TPMU_HA)}: BYTE
        [sensitiveType]sensitive:   TPMU_SENSITIVE_COMPOSITE (rsa, ecc, bits, sym, any)
            bits:   TPM2B_SENSITIVE_DATA (TPM_ALG_KEYEDHASH)
                size:                                           UINT16
                buffer[size]{: sizeof(TPMU_SENSITIVE_CREATE)}:  BYTE

"""

"""
TPM2B_PUBLIC
    size=:      UINT16
    publicArea: TPMT_PUBLIC
        type:               TPMI_ALG_PUBLIC
            TPM_ALG_!ALG.o
            #TPM_RC_TYPE
        nameAlg:            +TPMI_ALG_HASH
            TPM_ALG_!ALG.H
            +TPM_ALG_NULL
            #TPM_RC_HASH
        objectAttributes:   TPMA_OBJECT
        authPolicy:         TPM2B_DIGEST
            size:                           UINT16
            buffer[size]{:sizeof(TPMU_HA)}: BYTE
        [type]parameters:   TPMU_PUBLIC_PARMS (keyedHashDetail, symDetail, rsaDetail, eccDetail, asymDetail)
            eccDetail:      TPMS_ECC_PARMS
                symmetric:  TPMT_SYM_DEF_OBJECT+, not decryption, (TPM_ALG_NULL)
                    algorithm:              +TPMI_ALG_SYM_OBJECT (TPM_ALG_NULL)
                    [algorithm]keyBits:     TPMU_SYM_KEY_BITS
                        null:   TPM_ALG_NULL
                    [algorithm]mode:        TPMU_SYM_MODE
                        null:   TPM_ALG_NULL (?)
                    //[algorithm]details:   TPMU_SYM_DETAILS
                        null:   TPM_ALG_NULL (?)
                scheme:     TPMT_ECC_SCHEME+
                    scheme:             +TPMI_ALG_ECC_SCHEME
                        TPM_ALG_!ALG.ax
                        TPM_ALG_!ALG.am
                        +TPM_ALG_NULL
                        #TPM_RC_SCHEME
                    [scheme]details:    TPMU_ASYM_SCHEME
                        !ALG.am     TPMS_KEY_SCHEME_!ALG    TPM_ALG_!ALG
                        !ALG.ax     TPMS_SIG_SCHEME_!ALG    TPM_ALG_!ALG    (TPMI_ALG_ASYM_SCHEME) TPMT_ECC_SCHEME TPMI_ALG_ECC_SCHEME TPMI_ECC_SCHEME
                            TPMS_SCHEME_HASH
                                hashAlg:    TPMI_ALG_HASH
                curveID:    TPMI_ECC_CURVE
                    $ECC_CURVES
                    #TPM_RC_CURVE
                kdf:        TPMT_KDF_SCHEME+, (TPM_ALG_NULL)
                    scheme:             +TPMI_ALG_KDF
                        TPM_ALG_!ALG.HM
                        +TPM_ALG_NULL
                    [scheme]details:    TPMU_KDF_SCHEME
                        TPMS_SCHEME_!ALG.HM
                        TPM_ALG_NULL
            asymDetail:     TPMS_ASYM_PARMS
                symmetric:      TPMT_SYM_DEF_OBJECT+, not decryption, (TPM_ALG_NULL)
                scheme:         TPMT_ASYM_SCHEME+
                    scheme:             +TPMI_ALG_ASYM_SCHEME
                        TPM_ALG_!ALG.am
                        TPM_ALG_!ALG.ax (probable)
                        TPM_ALG_!ALG.ae
                        +TPM_ALG_NULL
                        #TPM_RC_VALUE
                    [scheme]details:    TPMU_ASYM_SCHEME
                        !ALG.ax     TPMS_SIG_SCHEME_!ALG    TPM_ALG_!ALG
                            TPMS_SCHEME_HASH
                                hashAlg:    TPMI_ALG_HASH
                                    TPM_ALG_!ALG.H
                                    +TPM_ALG_NULL
                                    #TPM_RC_HASH
        [type]unique:        TPMU_PUBLIC_ID (keyedHash, sym, rsa, ecc, derive)
            ecc:    TPMS_ECC_POINT (TPM_ALG_ECC)
                x:      TPM2B_ECC_PARAMETER
                    size:                               UINT16
                    buffer[size] {:MAX_ECC_KEY_BYTES}:  BYTE
                y:      TPM2B_ECC_PARAMETER
                    size:                               UINT16
                    buffer[size] {:MAX_ECC_KEY_BYTES}:  BYTE
"""

"""
TPMI_RH_HIERARCHY+
    TPM_RH_OWNER
    TPM_RH_PLATFORM
    TPM_RH_ENDORSEMENT
    +TPM_RH_NULL
    #TPM_RC_VALUE
"""


class TPMWarning(RuntimeWarning):
    pass


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
        response = self._write(payload)

        if len(response) < 10:
            raise OSError("Failed retrieving result from TPM module. Response: {}".format(response))
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

        F = bool(response_code & 0B00000000000000000000000010000000)

        if F:  # Format-One
            E = response_code & 0B00000000000000000000000000111111
            P = bool(response_code & 0B00000000000000000000000001000000)
            N = (response_code >> 8) & 0B00000000000000000000000000001111
            err_code = E + ResponseCodes.FMT1
            err_msg = ResponseCodes.RC_FMT1[err_code] if err_code in ResponseCodes.RC_FMT1 else "N/A"
            error = f"\033[31m\nError: 0x{err_code:x} {err_msg}\nType: {'parameter' if P else 'handle' if N < 16 else 'session'}\nNumber: {N & 0B111}\033[0m"
        else:  # Format-Zero
            E = response_code & 0B00000000000000000000000001111111
            V = bool(response_code & 0B00000000000000000000000100000000)
            T = bool(response_code & 0B00000000000000000000010000000000)
            S = bool(response_code & 0B00000000000000000000100000000000)
            err_code = E + (ResponseCodes.WARN if S else ResponseCodes.VER1)
            if S:
                err_msg = ResponseCodes.RC_WARN[err_code] if err_code in ResponseCodes.RC_WARN else "N/A"
            else:
                err_msg = ResponseCodes.RC_VER1[err_code] if err_code in ResponseCodes.RC_VER1 else "N/A"
            error = f"\033[31m\nError: 0x{err_code:x} {err_msg}\nVersion: {'2.0' if V else '<2.0'}\nImplementation: {'Vendor' if T else 'Specification'}\nSeverity: {'WARN' if S else 'ERR'}\033[0m"

        raise TPMWarning(error)


class BaseTPM2Operation:
    """Base TPM module operations class"""

    def __init__(self, device_cls):
        self._device = device_cls

    def startup(self, startup_type: int):
        device = self._device()
        tag, response_code, _ = device.send(
            False, CommandCodes.STARTUP, int(startup_type).to_bytes(2, "big", signed=False))
        device.validate(tag, response_code)

    def shutdown(self, shutdown_type: int):
        device = self._device()
        tag, response_code, _ = device.send(
            False, CommandCodes.SHUTDOWN, int(shutdown_type).to_bytes(2, "big", signed=False))
        device.validate(tag, response_code)

    def get_random(self, bytes_requested: int) -> bytes:
        device = self._device()
        tag, response_code, random_bytes = device.send(
            False, CommandCodes.GET_RANDOM, int(bytes_requested).to_bytes(2, "big", signed=False))

        device.validate(tag, response_code)
        return random_bytes

    def set_primary_policy(
            self, auth_handle: int, auth_policy: bytes = b"\x00\x00", hash_alg: int = AlgorithmConstants.NULL):
        """Set primary policy."""
        device = self._device()
        tag, response_code, _ = device.send(
            False, CommandCodes.SET_PRIMARY_POLICY,
            int(auth_handle).to_bytes(4, "big", signed=False) +
            int(len(auth_policy)).to_bytes(2, "big", signed=False) + auth_policy +
            int(hash_alg).to_bytes(2, "big", signed=False)
        )

        device.validate(tag, response_code)

    def verify_signature(self, key_handle: int, digest: bytes, signature: bytes) -> bool:
        device = self._device()
        tag, response_code, validation = device.send(
            False, CommandCodes.VERIFY_SIGNATURE,
            int(key_handle).to_bytes(4, "big", signed=False) +
            int(len(digest)).to_bytes(2, "big", signed=False) + digest +
            int(len(signature)).to_bytes(2, "big", signed=False) + signature
        )
        device.validate(tag, response_code)
        return True if validation[:2] == int(StructureTags.VERIFIED).to_bytes(2, "big", signed=False) else False

    def load(self, session: bool, parent_handle: int, in_private: bytes, in_public: bytes) -> Tuple[bytes, bytes]:
        device = self._device()
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
        device = self._device()
        if in_private is None:
            in_private = int(PermanentHandles.NULL).to_bytes(4, "big", signed=False)
        tag, response_code, result = device.send(
            session, CommandCodes.LOAD_EXTERNAL,
            in_private + in_public + hierarchy
        )
        device.validate(tag, response_code)
        object_handle = result[:4]
        length = int.from_bytes(result[4:6], "big", signed=False)
        name = result[6:]
        if len(name) != length:
            raise ValueError("Object handle invalid length.")
        return object_handle, name

    def evict_control(self, platform: bool, object_handle: int, persistent_handle: int):
        device = self._device()
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


    class TPM2Simulator(BaseTPM2Device):
        """Representation of current TPM simulator."""

        IP = ("127.0.0.1", 2321)
        PACKER = Struct("!HII")

        def __init__(self):
            self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self._socket.connect(self.IP)

        def __del__(self):
            if getattr(self, "_socket", None):
                self._socket.close()

        def _write(self, payload: bytes) -> bytes:
            if self._socket.send(payload) != len(payload):
                raise OSError("Error at TPM module, socket connection broken.")
            chunk = self._socket.recv(4096)
            if chunk == b"":
                raise OSError("Error at TPM module, socket connection broken.")
            return chunk


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
        device = self._device()
        tag, response_code, _ = device.send(
            True, CommandCodes.CLEAR, int(auth_handle).to_bytes(4, "big", signed=False))
        device.validate(tag, response_code)

    def get_capability(
            self, session: bool, capability: int, property: int, property_count: int
    ) -> Tuple[bool, bytes]:
        device = self._device()
        tag, response_code, data = device.send(
            session, CommandCodes.GET_CAPABILITY,
            int(capability).to_bytes(4, "big", signed=False) +
            int(property).to_bytes(4, "big", signed=False) +
            int(property_count).to_bytes(4, "big", signed=False)
        )
        device.validate(tag, response_code)
        more_data = bool(data[:1])
        capability_data = data[1:]
        if capability == Capabilities.ALGS:
            self._capability_algs(capability_data)
        elif capability == Capabilities.ECC_CURVES:
            self._capability_ecc(capability_data)
        elif capability == Capabilities.COMMANDS:
            self._capability_cc(capability_data)
        return more_data, capability_data

    def _capability_algs(self, capability_data: bytes):
        if int.from_bytes(capability_data[:4], "big", signed=False) != Capabilities.ALGS:
            raise TypeError("Requested algorithm capabilities but got different.")
        count = int.from_bytes(capability_data[5:8], "big", signed=False)
        data = capability_data[8:]
        if (count * 6) != len(data):
            raise TypeError("Capability data of wrong length")

        print("=" * 80)
        for step in range(count):
            idx = step * 6
            index = int.from_bytes(data[idx: idx + 2], "big", signed=False)
            print(hex(index), ALGORITHM_CONSTANTS[index] if index in ALGORITHM_CONSTANTS else "N/A")

    def _capability_ecc(self, capability_data: bytes):
        if int.from_bytes(capability_data[:4], "big", signed=False) != Capabilities.ECC_CURVES:
            raise TypeError("Requested algorithm capabilities but got different.")
        count = int.from_bytes(capability_data[5:8], "big", signed=False)
        data = capability_data[8:]
        if (count * 2) != len(data):
            raise TypeError("Capability data of wrong length")

        print("=" * 80)
        for step in range(count):
            idx = step * 2
            index = int.from_bytes(data[idx: idx + 2], "big", signed=False)
            print(hex(index), ECC_CURVE[index] if index in ECC_CURVE else "N/A")

    def _capability_cc(self, capability_data: bytes):
        if int.from_bytes(capability_data[:4], "big", signed=False) != Capabilities.COMMANDS:
            raise TypeError("Requested command code capabilities but got different.")
        count = int.from_bytes(capability_data[5:8], "big", signed=False)
        data = capability_data[8:]
        if (count * 4) != len(data):
            raise TypeError("Capability data of wrong length")

        print("=" * 80)
        for step in range(count):
            idx = step * 4
            command_index = int.from_bytes(data[idx + 2: idx + 4], "big", signed=False)
            print(hex(command_index), COMMAND_CODES[command_index] if command_index in COMMAND_CODES else "N/A")


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


# > openssl ec -in $HOME/mykey-prime256v1.pem -text -noout
PRIVKEY = """10:59:7d:ef:62:6c:db:83:5f:f5:9d:f4:67:e0:3e:30:9f:41:96:26:28:50:e6:09:45:8e:93:9c:11:e0:53:2c"""
PUBKEY = """04:7c:d7:1a:16:6c:e4:ee:69:ac:58:b1:49:f8:b8:ac:05:2a:11:ad:38:03:cb:b3:28:5a:fc:ac:91:e4:f2:79:ae:f3:00:03:54:b9:a3:86:5a:88:da:6e:1a:b2:fd:30:87:8b:1f:77:19:05:df:01:a1:bc:62:e6:97:0d:c4:b3:6d"""


def xy_from_pubkey(pubkey: str):
    code = "".join(pubkey.split(":")).encode()
    return binascii.unhexlify(code[2:66]), binascii.unhexlify(code[66:])


if __name__ == "__main__":
    device_cls = TPM2Device

    # ERROR 458 = INVALID ALGORITHM
    # ERROR 469 = INVALID LENGTH
    # ERROR 707 = INVALID HASH ALGORITHM
    # ERROR 714 = [maybe] INVALID LENGTH in_private
    # ERROR 722 = [maybe] INVALID scheme ALGORITHM

    TestOperation(device_cls).get_capability(False, Capabilities.ECC_CURVES, 0, 1024)

    # 1# Parameter
    auth = b""
    seed = b""
    bits = b""  # binascii.unhexlify("".join(PRIVKEY.split(":")).encode())
    sensitive_type = int(AlgorithmConstants.ECC).to_bytes(2, "big", signed=False)
    auth_value = int(len(auth)).to_bytes(2, "big", signed=False) + auth
    seed_value = int(len(seed)).to_bytes(2, "big", signed=False) + seed
    sensitive = int(len(bits)).to_bytes(2, "big", signed=False) + bits
    sensitive_area = sensitive_type + auth_value + seed_value + sensitive
    in_private = int(len(sensitive_area)).to_bytes(2, "big", signed=False) + sensitive_area

    # 2# Parameter
    x, y = xy_from_pubkey(PUBKEY)
    policy = b"\x00\x00\x00\x00"
    public_type = sensitive_type
    name_alg = int(AlgorithmConstants.SHA256).to_bytes(2, "big", signed=False)
    object_attributes = bytes(TPM2Object(False, False, False, False, False, False, False, False, False, False, False))
    auth_policy = int(len(policy)).to_bytes(2, "big", signed=False) + policy
    algorithm = int(AlgorithmConstants.NULL).to_bytes(2, "big", signed=False)
    algorithm_key_bits = int(AlgorithmConstants.NULL).to_bytes(2, "big", signed=False)
    algorithm_mode = int(AlgorithmConstants.NULL).to_bytes(2, "big", signed=False)
    algorithm_details = int(AlgorithmConstants.NULL).to_bytes(2, "big", signed=False)
    symmetric = algorithm + algorithm_key_bits + algorithm_mode + algorithm_details
    scheme = int(AlgorithmConstants.ECDSA).to_bytes(2, "big", signed=False)
    hash_alg = int(AlgorithmConstants.SHA256).to_bytes(2, "big", signed=False)
    curve_id = int(EccCurve.NIST_P256).to_bytes(2, "big", signed=False)
    kdf_scheme = int(AlgorithmConstants.NULL).to_bytes(2, "big", signed=False)
    kdf_scheme_detail = int(AlgorithmConstants.NULL).to_bytes(2, "big", signed=False)
    kdf = kdf_scheme + kdf_scheme_detail
    ecc_detail = symmetric + scheme + hash_alg + curve_id + kdf
    parameters = ecc_detail
    unique = int(len(x)).to_bytes(2, "big", signed=False) + x + int(len(y)).to_bytes(2, "big", signed=False) + y
    public_area = public_type + name_alg + object_attributes + auth_policy + parameters + unique
    in_public = int(len(public_area)).to_bytes(2, "big", signed=False) + public_area

    # 3# Parameter
    hierarchy = int(PermanentHandles.NULL).to_bytes(4, "big", signed=False)

    to = TestOperation(device_cls)
    handle, name = to.load_external(False, in_private, in_public, hierarchy)
    to.evict_control(True, None, handle)
    # pp = PhysicalPresence()
    # # print(pp.true_set_pp_required_for_clear())
    # print(pp.clear())
    # print(pp.version)
    # print(pp.tcg)
    # print(pp.vs)
    # print(TestOperation().reset())
