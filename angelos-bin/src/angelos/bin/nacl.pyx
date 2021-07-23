# cython: language_level=3, linetrace=True
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
"""Cython implementation of a libsodium wrapper."""
from typing import Union, Tuple

from angelos.bin.nacl cimport crypto_box_beforenm, crypto_box_zerobytes, \
    crypto_box_boxzerobytes, crypto_box_open_afternm, crypto_secretbox, crypto_secretbox_open, \
    crypto_secretbox_noncebytes, crypto_secretbox_keybytes, crypto_secretbox_zerobytes, \
    crypto_secretbox_boxzerobytes, crypto_sign_bytes, crypto_sign_secretkeybytes, \
    crypto_sign_publickeybytes, crypto_sign_seed_keypair, crypto_sign, crypto_sign_open, \
    randombytes, crypto_box_noncebytes, crypto_box_publickeybytes, crypto_box_secretkeybytes, \
    crypto_box_keypair, crypto_scalarmult_base, crypto_box_beforenmbytes, crypto_kx_publickeybytes, \
    crypto_kx_secretkeybytes, crypto_kx_sessionkeybytes, crypto_kx_client_session_keys, \
    crypto_kx_server_session_keys, crypto_aead_xchacha20poly1305_ietf_npubbytes, \
    crypto_aead_xchacha20poly1305_ietf_keybytes, crypto_aead_xchacha20poly1305_ietf_abytes, \
    crypto_aead_xchacha20poly1305_ietf_encrypt, crypto_aead_xchacha20poly1305_ietf_decrypt, \
    crypto_generichash_keybytes, crypto_generichash, crypto_generichash_bytes, \
    crypto_generichash_bytes_min, crypto_generichash_bytes_max, sodium_base64_VARIANT_URLSAFE, \
    sodium_base64_encoded_len, crypto_scalarmult, \
    crypto_scalarmult_scalarbytes, crypto_scalarmult_bytes, sodium_init, crypto_aead_chacha20poly1305_encrypt, \
    crypto_aead_chacha20poly1305_decrypt, crypto_aead_chacha20poly1305_keybytes, \
    crypto_aead_chacha20poly1305_npubbytes, crypto_aead_chacha20poly1305_abytes


class NaClError(RuntimeError):
    """Error due to programmatic misuse."""
    KEY_LENGTH_ERROR = ("Invalid key due to length.", 100)
    KEY_COMPUTATION_ERROR = ("Key computation failed", 101)
    KEY_GENERATION_ERROR = ("Failed generate key(s)", 102)
    DATA_LENGTH_ERROR = ("Data is to long", 103)
    HASH_LENGTH_BOUNDARIES = ("Hash length outside boundaries", 104)
    NONCE_LENGTH_ERROR = ("Invalid nonce due to length", 105)
    INITIALIZE_ERROR = ("Libsodium failed to initialize", 106)


class CryptoFailure(RuntimeWarning):
    """When crypto operation fail due to circumstantial reasons."""
    pass

class HashFailure(RuntimeWarning):
    """When hash operation fail due to circumstantial reasons."""


if sodium_init() == -1:
    raise NaClError(*NaClError.INITIALIZE_ERROR)


SIZE_BOX_NONCE = crypto_box_noncebytes()

SIZE_SECRETBOX_NONCE = crypto_secretbox_noncebytes()
SIZE_SECRETBOX_KEY = crypto_secretbox_keybytes()
SIZE_SECRETBOX_ZERO = crypto_secretbox_zerobytes()
SIZE_SECRETBOX_BOXZERO = crypto_secretbox_boxzerobytes()

SIZE_SIGN_SEED = crypto_sign_secretkeybytes() // 2
SIZE_SIGN = crypto_sign_bytes()
SIZE_SIGN_SECRETKEY = crypto_sign_secretkeybytes()
SIZE_SIGN_PUBLICKEY = crypto_sign_publickeybytes()

SIZE_BOX_PUBLICKEY = crypto_box_publickeybytes()
SIZE_BOX_SECRETKEY = crypto_box_secretkeybytes()
SIZE_BOX_BEFORENM = crypto_box_beforenmbytes()
SIZE_BOX_ZERO = crypto_box_zerobytes()
SIZE_BOX_BOXZERO = crypto_box_boxzerobytes()

SIZE_KX_PUBLICKEY = crypto_kx_publickeybytes()
SIZE_KX_SECRETKEY = crypto_kx_secretkeybytes()
SIZE_KX_SESSIONKEY = crypto_kx_sessionkeybytes()

SIZE_AEAD_NPUB = crypto_aead_xchacha20poly1305_ietf_npubbytes()
SIZE_AEAD_KEY = crypto_aead_xchacha20poly1305_ietf_keybytes()
SIZE_AEAD_A = crypto_aead_xchacha20poly1305_ietf_abytes()

SIZE_HASH_KEY = crypto_generichash_keybytes()
SIZE_HASH_BYTES = crypto_generichash_bytes()
SIZE_HASH_BYTES_MIN = crypto_generichash_bytes_min()
SIZE_HASH_BYTES_MAX = crypto_generichash_bytes_max()

SIZE_SCALARMULT_SCALARBYTES = crypto_scalarmult_scalarbytes()
SIZE_SCALARMULT_BYTES = crypto_scalarmult_bytes()

SIZE_AEAD_CCP_NONCE = crypto_aead_chacha20poly1305_npubbytes()
SIZE_AEAD_CCP_KEY = crypto_aead_chacha20poly1305_keybytes()
SIZE_AEAD_CCP_BYTES = crypto_aead_chacha20poly1305_abytes()

BASE64_VARIANT_URLSAFE = sodium_base64_VARIANT_URLSAFE


class NaCl:
    @classmethod
    def random_bytes(cls, unsigned int size) -> bytes:
        buffer = bytes(size)
        randombytes(buffer, size)
        return buffer

    @classmethod
    def random_nonce(cls) -> bytes:
        return cls.random_bytes(SIZE_SECRETBOX_NONCE)

    @classmethod
    def random_aead_nonce(cls) -> bytes:
        return cls.random_bytes(SIZE_AEAD_NPUB)

    @classmethod
    def salsa_key(cls) -> bytes:
        return cls.random_bytes(SIZE_SECRETBOX_KEY)


class BaseKey:
    """Base class for encryption and signing keys."""

    def __init__(self):
        self._sk = None
        self._pk = None
        self._vk = None
        self._seed = None

    @property
    def sk(self) -> bytes:
        """Secret key."""
        return self._sk

    @property
    def pk(self) -> bytes:
        """Public key."""
        return self._pk

    @property
    def vk(self) -> bytes:
        """Verification key."""
        return self._vk

    @property
    def seed(self) -> bytes:
        """Signature seed."""
        return self._seed


class SecretBox(BaseKey):
    def __init__(self, key: bytes = None):
        BaseKey.__init__(self)

        self._sk = key

        if self._sk is None:
            self._sk = NaCl.salsa_key()
        if len(self._sk) != SIZE_SECRETBOX_KEY:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)

    def encrypt(self, message: bytes) -> bytes:
        nonce = NaCl.random_nonce()
        pad = bytes(SIZE_SECRETBOX_ZERO) + message
        pad_len = len(pad)
        crypto = bytes(pad_len)
        fail = crypto_secretbox(crypto, pad, pad_len, nonce, self._sk)
        if fail:
            raise CryptoFailure()
        return nonce + crypto[SIZE_SECRETBOX_BOXZERO:]

    def decrypt(self, crypto: bytes) -> bytes:
        nonce = crypto[:SIZE_SECRETBOX_NONCE]
        crypto = crypto[SIZE_SECRETBOX_NONCE:]
        pad = bytes(SIZE_SECRETBOX_BOXZERO) + crypto
        pad_len = len(pad)
        message = bytes(pad_len)
        fail = crypto_secretbox_open(message, pad, pad_len, nonce, self._sk)
        if fail:
            raise CryptoFailure()
        return message[SIZE_SECRETBOX_ZERO:]


class Signer(BaseKey):
    def __init__(self, seed: bytes = None):
        BaseKey.__init__(self)

        self._seed = seed

        if self._seed:
            if len(self._seed) != SIZE_SIGN_SEED:
                raise NaClError(*NaClError.KEY_LENGTH_ERROR)
        else:
            self._seed = NaCl.random_bytes(SIZE_SIGN_SEED)

        self._sk = bytes(SIZE_SIGN_SECRETKEY)
        self._vk = bytes(SIZE_SIGN_PUBLICKEY)

        fail = crypto_sign_seed_keypair(self._vk, self._sk, self._seed)
        if fail:
            raise NaClError(*NaClError.KEY_GENERATION_ERROR)

    def sign(self, message):
        cdef unsigned long long *sig_len = NULL
        msg_len = len(message)
        signature = bytes(msg_len + SIZE_SIGN)
        fail = crypto_sign(signature, sig_len, message, msg_len, self._sk)
        if fail:
            raise CryptoFailure()

        return signature

    def signature(self, message: bytes) -> bytes:
        return self.sign(message)[:SIZE_SIGN]


class Verifier(BaseKey):
    def __init__(self, vk: bytes):
        BaseKey.__init__(self)

        if len(vk) != SIZE_SIGN_PUBLICKEY:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)

        self._vk = vk

    def verify(self, signature: bytes) -> bytes:
        cdef unsigned long long msg_len
        cdef unsigned long long *msg_len_p = NULL
        msg_len_p = &msg_len

        sig_len = len(signature)
        message = bytes(sig_len)

        fail = crypto_sign_open(message, msg_len_p, signature, sig_len, self._vk)
        if fail:
            raise CryptoFailure()
        return message[:msg_len]


class PublicKey(BaseKey):
    def __init__(self, pk: bytes):
        BaseKey.__init__(self)

        if len(pk) != SIZE_BOX_PUBLICKEY:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR, SIZE_BOX_PUBLICKEY, len(pk))

        self._pk = pk


class SecretKey(BaseKey):
    def __init__(self, sk: bytes = None):
        BaseKey.__init__(self)
        self._sk = sk
        self._pk = bytes(SIZE_BOX_PUBLICKEY)

        if self._sk is None:
            self._sk = bytes(SIZE_BOX_SECRETKEY)
            crypto_box_keypair(self._pk, self._sk)
        elif len(self._sk) == SIZE_BOX_SECRETKEY:
            if crypto_scalarmult_base(self._pk, self._sk):
                raise NaClError(*NaClError.KEY_COMPUTATION_ERROR)
        else:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR, SIZE_BOX_SECRETKEY, len(sk))


class DualSecret(BaseKey):
    def __init__(self, sk: bytes = None, seed: bytes = None):
        BaseKey.__init__(self)

        self.__crypt = SecretKey(sk)
        self.__signer = Signer(seed)

        self._sk = self.__crypt.sk
        self._pk = self.__crypt.pk
        self._seed = self.__signer.seed
        self._vk = self.__signer.vk

    def sign(self, message: bytes) -> bytes:
        return self.__signer.sign(message)

    def signature(self, message: bytes) -> bytes:
        return self.__signer.signature(message)


class CryptoBox:
    def __init__(self, sk: Union[SecretKey, DualSecret], pk: PublicKey):
        sk = sk.sk
        pk = pk.pk

        if pk and sk:
            self._k = bytes(SIZE_BOX_BEFORENM)
            fail = crypto_box_beforenm(self._k, pk, sk)
            if fail:
                raise NaClError(*NaClError.KEY_COMPUTATION_ERROR)

    def encrypt(self, message: bytes) -> bytes:
        nonce = NaCl.random_nonce()
        pad = bytes(SIZE_BOX_ZERO) + message
        pad_len = len(pad)
        crypto = bytes(pad_len)
        fail = crypto_box_afternm(crypto, pad, pad_len, nonce, self._k)
        if fail:
            raise CryptoFailure()

        return nonce + crypto[SIZE_BOX_BOXZERO:]

    def decrypt(self, crypto: bytes) -> bytes:
        nonce = crypto[:SIZE_BOX_NONCE]
        crypto = crypto[SIZE_BOX_NONCE:]
        pad = bytes(SIZE_BOX_BOXZERO) + crypto
        pad_len = len(pad)
        message = bytes(pad_len)
        fail = crypto_box_open_afternm(message, pad, pad_len, nonce, self._k)
        if fail:
            raise CryptoFailure()

        return message[SIZE_BOX_ZERO:]


class NetworkBox:
    def __init__(self, us: SecretKey, them: PublicKey):
        self._them = them
        if len(self._them.pk) != SIZE_KX_PUBLICKEY:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)

        self._us = us
        if len(self._us.sk) != SIZE_KX_SECRETKEY or len(self._us.pk) != SIZE_KX_PUBLICKEY:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)

        self._tx = bytes(SIZE_KX_SESSIONKEY)
        self._rx = bytes(SIZE_KX_SESSIONKEY)

    def encrypt(self, message: bytes, data: bytes) -> bytes:
        cdef unsigned long long crypto_len
        cdef unsigned long long *crypto_len_p = NULL
        crypto_len_p = &crypto_len

        data_len = len(data)
        if len(data_len) > 255:
            raise NaClError(*NaClError.DATA_LENGTH_ERROR)

        msg_len = len(message)
        crypto = bytes(msg_len + SIZE_AEAD_A)
        nonce = NaCl.random_aead_nonce()
        fail = crypto_aead_xchacha20poly1305_ietf_encrypt(
            crypto, crypto_len_p,
            message, msg_len,
            data, data_len, NULL, nonce, self._tx
        )
        if fail:
            raise CryptoFailure()
        return str(chr(data_len)).encode() + data + nonce + crypto

    def decrypt(self, crypto: bytes) -> Tuple[bytes, bytes]:
        cdef unsigned long long msg_len
        cdef unsigned long long *msg_len_p = NULL
        msg_len_p = &msg_len

        data_len = ord(crypto[0])
        data = crypto[1:data_len]
        nonce = crypto[1+data_len:1+data_len+SIZE_AEAD_NPUB]
        message = bytes(len(crypto) - 1+data_len+SIZE_AEAD_NPUB - SIZE_AEAD_A)

        fail = crypto_aead_xchacha20poly1305_ietf_decrypt(
            message, msg_len_p,
            NULL,
            crypto[1+data_len+SIZE_AEAD_NPUB:], len(crypto[1+data_len+SIZE_AEAD_NPUB:]),
            data, data_len, nonce, self._rx
        )

        if fail:
            raise CryptoFailure()

        return message, data


class ServerBox(NetworkBox):
    def __init__(self, server: SecretKey, client: PublicKey):
        NetworkBox.__init__(self, server, client)
        fail = crypto_kx_server_session_keys(self._rx, self._tx, self._us.sk, self._us.pk, self._them.pk)
        if fail:
            raise CryptoFailure()


class ClientBox:
    def __init__(self, client: SecretKey, server: PublicKey):
        NetworkBox.__init__(self, client, server)
        fail = crypto_kx_client_session_keys(self._rx, self._tx, self._us.sk, self._us.pk, self._them.pk)
        if fail:
            raise CryptoFailure()


class Backend_25519_ChaChaPoly_BLAKE2b:
    """Noise protocol crypto functions using libsodium for backend."""

    __slots__ = ("_hash_key", "_digest")

    def __init__(self, hash_key_size: int = SIZE_HASH_KEY, hash_digest_size: int = SIZE_HASH_BYTES):
        if SIZE_HASH_BYTES_MIN > hash_digest_size > SIZE_HASH_BYTES_MAX:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)
        self._hash_key = hash_key_size

        if SIZE_HASH_BYTES_MIN > hash_digest_size > SIZE_HASH_BYTES_MAX:
            raise NaClError(*NaClError.HASH_LENGTH_BOUNDARIES)
        self._digest = hash_digest_size

    @property
    def key_size(self) -> int:
        return self._hash_key

    @property
    def digest_size(self) -> int:
        return self._digest

    @property
    def dhlen(self):
        return 32

    @property
    def hashlen(self):
        return 64

    @property
    def blocklen(self):
        return 128

    def _generate(self) -> SecretKey:
        """Generate a new Curve25519 keypair."""
        sk = bytes(SIZE_BOX_SECRETKEY)
        randombytes(sk, SIZE_BOX_SECRETKEY)
        return SecretKey(sk)

    def _hash(self, data: bytes) -> bytes:
        digest = bytes(self._digest)
        fail = crypto_generichash(digest, self._digest, data, len(data), NULL, 0)

        if fail != 0:
            raise HashFailure()

        return digest

    def _hkdf2(self, chaining_key: bytes, input_key_material: bytes) -> Tuple[bytes, bytes]:
        if len(chaining_key) != self._hash_key:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)
        if self._digest != self._hash_key:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)

        temp_key = bytes(self._digest)
        fail = crypto_generichash(
            temp_key, self._digest, input_key_material, len(input_key_material), chaining_key, self._hash_key)
        if fail != 0:
            raise HashFailure()

        output1 = bytes(self._digest)
        fail = crypto_generichash(output1, self._digest, b"\x01", 1, temp_key, self._digest)
        if fail != 0:
            raise HashFailure()

        output2 = bytes(self._digest)
        fail = crypto_generichash(output2, self._digest, output1 + b"\x02", self._digest + 1, temp_key, self._digest)
        if fail != 0:
            raise HashFailure()

        return output1, output2

    def _hkdf3(self, chaining_key: bytes, input_key_material: bytes) -> Tuple[bytes, bytes, bytes]:
        if len(chaining_key) != self._hash_key:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)
        if self._digest != self._hash_key:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)

        temp_key = bytes(self._digest)
        fail = crypto_generichash(
            temp_key, self._digest, input_key_material, len(input_key_material), chaining_key, self._hash_key)
        if fail != 0:
            raise HashFailure()

        output1 = bytes(self._digest)
        fail = crypto_generichash(output1, self._digest, b"\x01", 1, temp_key, self._digest)
        if fail != 0:
            raise HashFailure()

        output2 = bytes(self._digest)
        fail = crypto_generichash(output2, self._digest, output1 + b"\x02", self._digest + 1, temp_key, self._digest)
        if fail != 0:
            raise HashFailure()

        output3 = bytes(self._digest)
        fail = crypto_generichash(output3, self._digest, output2 + b"\x03", self._digest + 1, temp_key, self._digest)
        if fail != 0:
            raise HashFailure()

        return output1, output2, output3

    def _dh(self, our_secret: bytes, their_public: bytes) -> bytes:
        if len(our_secret) != SIZE_SCALARMULT_SCALARBYTES or len(their_public) != SIZE_SCALARMULT_BYTES:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)

        shared = bytes(SIZE_SCALARMULT_BYTES)
        fail = crypto_scalarmult(shared, our_secret, their_public)

        if fail != 0:
            raise HashFailure()

        return shared

    def _encrypt(self, key: bytes, nonce: bytes, message: bytes, additional: bytes = None) -> bytes:
        if len(key) != SIZE_AEAD_CCP_KEY:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)
        if len(nonce) != SIZE_AEAD_CCP_NONCE:
            raise NaClError(*NaClError.NONCE_LENGTH_ERROR)

        msg_len = len(message)
        cdef unsigned long long cipher_len
        cdef unsigned long long *cipher_len_p = NULL
        cipher_len_p = &cipher_len
        cipher = bytes(SIZE_AEAD_CCP_BYTES + msg_len)

        fail = 0
        if additional:
            fail = crypto_aead_chacha20poly1305_encrypt(
                cipher, cipher_len_p, message, msg_len, additional, len(additional), NULL, nonce, key)
        else:
            fail = crypto_aead_chacha20poly1305_encrypt(
                cipher, cipher_len_p, message, msg_len, NULL, 0, NULL, nonce, key)

        if fail != 0:
            raise CryptoFailure()

        return cipher[:cipher_len]

    def _decrypt(self, key: bytes, nonce: bytes, cipher: bytes, additional: bytes = None) -> bytes:
        if len(key) != SIZE_AEAD_CCP_KEY:
            raise NaClError(*NaClError.KEY_LENGTH_ERROR)
        if len(nonce) != SIZE_AEAD_CCP_NONCE:
            raise NaClError(*NaClError.NONCE_LENGTH_ERROR)

        cipher_len = len(cipher)
        cdef unsigned long long msg_len
        cdef unsigned long long *msg_len_p = NULL
        msg_len_p = &msg_len
        message = bytes(cipher_len - SIZE_AEAD_CCP_BYTES)

        fail = 0
        if additional:
            fail = crypto_aead_chacha20poly1305_decrypt(
                message, msg_len_p, NULL, cipher, cipher_len, additional, len(additional), nonce, key)
        else:
            fail = crypto_aead_chacha20poly1305_decrypt(
                message, msg_len_p, NULL, cipher, cipher_len, NULL, 0, nonce, key)

        if fail != 0:
            raise CryptoFailure()

        return message[:msg_len]