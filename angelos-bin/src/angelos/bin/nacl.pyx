# cython: language_level=3
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
from typing import Union

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
    crypto_aead_xchacha20poly1305_ietf_encrypt, crypto_aead_xchacha20poly1305_ietf_decrypt


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
        buffer = bytes(size)
        randombytes(buffer, size)
        return buffer

    @staticmethod
    def rand_nonce() -> bytes:
        return BaseKey.randombytes(SIZE_SECRETBOX_NONCE)

    @staticmethod
    def rand_aead_nonce() -> bytes:
        return BaseKey.randombytes(SIZE_AEAD_NPUB)

    def _salsa_key(self) -> bytes:
        return BaseKey.randombytes(SIZE_SECRETBOX_KEY)


class SecretBox(BaseKey):
    def __init__(self, key: bytes = None):
        BaseKey.__init__(self)

        self._sk = key

        if self._sk is None:
            self._sk = self._salsa_key()
        if len(self._sk) != SIZE_SECRETBOX_KEY:
            raise ValueError('Invalid key')

    def encrypt(self, message: bytes) -> bytes:
        nonce = BaseKey.rand_nonce()
        pad = bytes(SIZE_SECRETBOX_ZERO) + message
        pad_len = len(pad)
        crypto = bytes(pad_len)
        fail = crypto_secretbox(crypto, pad, pad_len, nonce, self._sk)
        if fail:
            raise ValueError("Failed to encrypt message")
        return nonce + crypto[SIZE_SECRETBOX_BOXZERO:]

    def decrypt(self, crypto: bytes) -> bytes:
        nonce = crypto[:SIZE_SECRETBOX_NONCE]
        crypto = crypto[SIZE_SECRETBOX_NONCE:]
        pad = bytes(SIZE_SECRETBOX_BOXZERO) + crypto
        pad_len = len(pad)
        message = bytes(pad_len)
        fail = crypto_secretbox_open(message, pad, pad_len, nonce, self._sk)
        if fail:
            raise ValueError("Failed to decrypt message")
        return message[SIZE_SECRETBOX_ZERO:]


class Signer(BaseKey):
    def __init__(self, seed: bytes = None):
        BaseKey.__init__(self)

        self._seed = seed

        if self._seed:
            if len(self._seed) != SIZE_SIGN_SEED:
                raise ValueError("Invalid seed bytes")
        else:
            self._seed = BaseKey.randombytes(SIZE_SIGN_SEED)

        self._sk = bytes(SIZE_SIGN_SECRETKEY)
        self._vk = bytes(SIZE_SIGN_PUBLICKEY)

        fail = crypto_sign_seed_keypair(self._vk, self._sk, self._seed)
        if fail:
            raise RuntimeError("Failed to generate key-pair from seed")

    def sign(self, message):
        cdef unsigned long long *sig_len = NULL
        msg_len = len(message)
        signature = bytes(msg_len + SIZE_SIGN)
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
        message = bytes(sig_len)

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

        self._sk = sk
        self._pk = bytes(SIZE_BOX_PUBLICKEY)

        if self._sk is None:
            self._sk = bytes(SIZE_BOX_SECRETKEY)
            crypto_box_keypair(self._pk, self._sk)
        elif len(self._sk) == SIZE_BOX_SECRETKEY:
            if crypto_scalarmult_base(self._pk, self._sk):
                raise RuntimeError("Failed to compute scalar product")
        else:
            raise ValueError("Passed in invalid secret key")


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
                raise RuntimeError("Unable to compute shared key")

    def encrypt(self, message: bytes) -> bytes:
        nonce = BaseKey.rand_nonce()
        pad = bytes(SIZE_BOX_ZERO) + message
        pad_len = len(pad)
        crypto = bytes(pad_len)
        fail = crypto_box_afternm(crypto, pad, pad_len, nonce, self._k)
        if fail:
            raise RuntimeError("Unable to encrypt messsage")

        return nonce + crypto[SIZE_BOX_BOXZERO:]

    def decrypt(self, crypto: bytes) -> bytes:
        nonce = crypto[:SIZE_BOX_NONCE]
        crypto = crypto[SIZE_BOX_NONCE:]
        pad = bytes(SIZE_BOX_BOXZERO) + crypto
        pad_len = len(pad)
        message = bytes(pad_len)
        fail = crypto_box_open_afternm(message, pad, pad_len, nonce, self._k)
        if fail:
            raise RuntimeError("Unable to decrypt message")

        return message[SIZE_BOX_ZERO:]


class NetworkBox:
    def __init__(self, us: SecretKey, them: PublicKey):
        self._them = them
        if len(self._them.pk) != SIZE_KX_PUBLICKEY:
            raise ValueError("Invalid public key bytes")

        self._us = us
        if len(self._us.sk) != SIZE_KX_SECRETKEY or len(self._us.pk) != SIZE_KX_PUBLICKEY:
            raise RuntimeError("Passed in invalid secret key")

        self._tx = bytes(SIZE_KX_SESSIONKEY)
        self._rx = bytes(SIZE_KX_SESSIONKEY)

    def encrypt(self, message: bytes, data: bytes) -> bytes:
        cdef unsigned long long crypto_len

        data_len = len(data)
        if len(data_len) > 255:
            raise ValueError("Data can not be longer than 255 bytes.")

        msg_len = len(message)
        crypto = bytes(msg_len + SIZE_AEAD_A)
        nonce = BaseKey.rand_aead_nonce()
        fail = crypto_aead_xchacha20poly1305_ietf_encrypt(
            crypto, crypto_len,
            message, msg_len,
            data, data_len, NULL, nonce, self._tx
        )
        if fail:
            raise RuntimeError("Unable to encrypt messsage")
        return str(chr(data_len)).encode() + data + nonce + crypto

    def decrypt(self, crypto: bytes) -> (bytes, bytes):
        cdef unsigned long long msg_len

        data_len = ord(crypto[0])
        data = crypto[1:data_len]
        nonce = crypto[1+data_len:1+data_len+SIZE_AEAD_NPUB]
        message = bytes(len(crypto) - 1+data_len+SIZE_AEAD_NPUB - SIZE_AEAD_A)

        fail = crypto_aead_xchacha20poly1305_ietf_decrypt(
            message, msg_len,
            NULL,
            crypto[1+data_len+SIZE_AEAD_NPUB:], len(crypto[1+data_len+SIZE_AEAD_NPUB:]),
            data, data_len, nonce, self._rx
        )

        if fail:
            raise RuntimeError("Unable to decrypt message")

        return message, data

    def decrypt(self, ctxt, aadLen):
        '''
        Decrypt the given message, if no nonce or aad are given they will be
        extracted from the message
        '''
        aad = ctxt[:aadLen]
        nonce = ctxt[aadLen:aadLen+libnacl.crypto_aead_aes256gcm_NPUBBYTES]
        ctxt = ctxt[aadLen+libnacl.crypto_aead_aes256gcm_NPUBBYTES:]
        if len(nonce) != libnacl.crypto_aead_aes256gcm_NPUBBYTES:
            raise ValueError('Invalid nonce')
        if self.usingAES:
            return libnacl.crypto_aead_aes256gcm_decrypt(ctxt, aad, nonce, self.sk)
        return libnacl.crypto_aead_chacha20poly1305_ietf_decrypt(ctxt, aad, nonce, self.sk)


class ServerBox(NetworkBox):
    def __init__(self, server: SecretKey, client: PublicKey):
        NetworkBox.__init__(self, server, client)
        fail = crypto_kx_server_session_keys(self._rx, self._tx, self._us.sk, self._us.pk, self._them.pk)
        if fail:
            raise RuntimeError("Suspicious client public key")


class ClientBox:
    def __init__(self, client: SecretKey, server: PublicKey):
        NetworkBox.__init__(self, client, server)
        fail = crypto_kx_client_session_keys(self._rx, self._tx, self._us.sk, self._us.pk, self._them.pk)
        if fail:
            raise RuntimeError("Suspicious server public key")
