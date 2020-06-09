# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Cython implementation of a libsodium wrapper."""
from typing import Union

from libangelos.library.nacl cimport crypto_box_beforenm, crypto_box_zerobytes, \
    crypto_box_boxzerobytes, crypto_box_open_afternm, crypto_secretbox, crypto_secretbox_open, \
    crypto_secretbox_noncebytes, crypto_secretbox_keybytes, crypto_secretbox_zerobytes, \
    crypto_secretbox_boxzerobytes, crypto_sign_bytes, crypto_sign_secretkeybytes, \
    crypto_sign_publickeybytes, crypto_sign_seed_keypair, crypto_sign, crypto_sign_open, \
    randombytes, crypto_box_noncebytes, crypto_box_publickeybytes, crypto_box_secretkeybytes, \
    crypto_box_keypair, crypto_scalarmult_base, crypto_box_beforenmbytes


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

    @staticmethod
    def randombytes(unsigned int size) -> bytes:
        buffer = b"\00" * size
        randombytes(buffer, size)
        return buffer

    @staticmethod
    def rand_nonce() -> bytes:
        return BaseKey.randombytes(SIZE_SECRETBOX_NONCE)

    def _salsa_key(self) -> bytes:
        return BaseKey.randombytes(SIZE_SECRETBOX_KEY)


class SecretBox(BaseKey):
    def __init__(self, key: bytes = None):
        BaseKey.__init__(self)

        if key is None:
            key = self._salsa_key()
        if len(key) != SIZE_SECRETBOX_KEY:
            raise ValueError('Invalid key')
        self._sk = key

    def encrypt(self, message: bytes) -> bytes:
        nonce = BaseKey.rand_nonce()
        pad = b"\x00" * SIZE_SECRETBOX_ZERO + message
        pad_len = len(pad)
        crypto = b"\x00" * pad_len
        fail = crypto_secretbox(crypto, pad, pad_len, nonce, self._sk)
        if fail:
            raise ValueError("Failed to encrypt message")
        return nonce + crypto[SIZE_SECRETBOX_BOXZERO:]

    def decrypt(self, crypto: bytes) -> bytes:
        nonce = crypto[:SIZE_SECRETBOX_NONCE]
        crypto = crypto[SIZE_SECRETBOX_NONCE:]
        pad = b"\x00" * SIZE_SECRETBOX_BOXZERO + crypto
        pad_len = len(pad)
        message = b"\x00" * pad_len
        fail = crypto_secretbox_open(message, pad, pad_len, nonce, self._sk)
        if fail:
            raise ValueError("Failed to decrypt message")
        return message[SIZE_SECRETBOX_ZERO:]


class Signer(BaseKey):
    def __init__(self, seed: bytes = None):
        BaseKey.__init__(self)

        if seed:
            if len(seed) != SIZE_SIGN_SEED:
                raise ValueError("Invalid seed bytes")
        else:
            seed = BaseKey.randombytes(SIZE_SIGN_SEED)

        sk = b"\00" * SIZE_SIGN_SECRETKEY
        vk = b"\00" * SIZE_SIGN_PUBLICKEY

        fail = crypto_sign_seed_keypair(vk, sk, seed)
        if fail:
            raise RuntimeError("Failed to generate keypair from seed")

        self._seed = seed
        self._sk = sk
        self._vk = vk

    def sign(self, message):
        cdef unsigned long long *sig_len = NULL
        msg_len = len(message)
        signature = b"\x00" * (msg_len + SIZE_SIGN)
        fail = crypto_sign(signature, sig_len, message, msg_len, self._sk)
        if fail:
            raise ValueError('Failed to sign message')

        return signature

    def signature(self, message: bytes) -> bytes:
        return self.sign(message)[:SIZE_SIGN]


class Verifier(BaseKey):
    def __init__(self, vk: bytes):
        BaseKey.__init__(self)

        if len(vk) != SIZE_SIGN_PUBLICKEY:
            raise ValueError("Invalid public key")

        self._vk = vk

    def verify(self, signature: bytes) -> bytes:
        cdef unsigned long long msg_len
        cdef unsigned long long *msg_len_p = NULL
        msg_len_p = &msg_len

        sig_len = len(signature)
        message = b"\x00" * sig_len

        fail = crypto_sign_open(message, msg_len_p, signature, sig_len, self._vk)
        if fail:
            raise ValueError("Failed to validate message")
        return message[:msg_len]


class PublicKey(BaseKey):
    def __init__(self, pk: bytes):
        BaseKey.__init__(self)

        if len(pk) != SIZE_BOX_PUBLICKEY:
            raise ValueError("Passed in invalid public key")

        self._pk = pk


class SecretKey(BaseKey):
    def __init__(self, sk: bytes = None):
        BaseKey.__init__(self)

        pk = b"\x00" * SIZE_BOX_PUBLICKEY

        if sk is None:
            sk = b"\x00" * SIZE_BOX_SECRETKEY
            crypto_box_keypair(pk, sk)
        elif len(sk) == SIZE_BOX_SECRETKEY:
            if crypto_scalarmult_base(pk, sk):
                raise RuntimeError("Failed to compute scalar product")
        else:
            raise ValueError("Passed in invalid secret key")

        self._pk = pk
        self._sk = sk


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
            k = b"\x00" * SIZE_BOX_BEFORENM
            fail = crypto_box_beforenm(k, pk, sk)
            if fail:
                raise RuntimeError("Unable to compute shared key")
            self._k = k

    def encrypt(self, message: bytes) -> bytes:
        nonce = BaseKey.rand_nonce()
        pad = b"\x00" * SIZE_BOX_ZERO + message
        pad_len = len(pad)
        crypto = b"\x00" * pad_len
        fail = crypto_box_afternm(crypto, pad, pad_len, nonce, self._k)
        if fail:
            raise RuntimeError("Unable to encrypt messsage")

        return nonce + crypto[SIZE_BOX_BOXZERO:]

    def decrypt(self, crypto: bytes) -> bytes:
        nonce = crypto[:SIZE_BOX_NONCE]
        crypto = crypto[SIZE_BOX_NONCE:]
        pad = b"\x00" * SIZE_BOX_BOXZERO + crypto
        pad_len = len(pad)
        message = b"\x00" * pad_len
        fail = crypto_box_open_afternm(message, pad, pad_len, nonce, self._k)
        if fail:
            raise RuntimeError("Unable to decrypt message")

        return message[SIZE_BOX_ZERO:]
