# Copyright (c) 2013-2018 by Ron Frederick <ronf@timeheart.net> and others.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License v2.0 which accompanies this
# distribution and is available at:
#
#     http://www.eclipse.org/legal/epl-2.0/
#
# This program may also be made available under the following secondary
# licenses when the conditions for such availability set forth in the
# Eclipse Public License v2.0 are satisfied:
#
#    GNU General Public License, Version 2.0, or any later versions of
#    that license
#
# SPDX-License-Identifier: EPL-2.0 OR GPL-2.0-or-later
#
# Contributors:
#     Ron Frederick - initial implementation, API, and documentation

"""Symmetric key encryption handlers"""

from .crypto import BasicCipher, GCMCipher, ChachaCipher, get_cipher_params
from .mac import get_mac_params, get_mac
from .packet import UInt64


_enc_algs = []
_enc_params = {}


class Encryption:
    """Parent class for SSH packet encryption objects"""

    @classmethod
    def new(cls, cipher_name, key, iv, mac_alg=b'', mac_key=b'', etm=False):
        """Construct a new SSH packet encryption object"""

        raise NotImplementedError

    @classmethod
    def get_mac_params(cls, mac_alg):
        """Get paramaters of the MAC algorithm used with this encryption"""

        return get_mac_params(mac_alg)

    def encrypt_packet(self, seq, header, packet):
        """Encrypt and sign an SSH packet"""

        raise NotImplementedError

    def decrypt_header(self, seq, first_block, header_len):
        """Decrypt an SSH packet header"""

        raise NotImplementedError

    def decrypt_packet(self, seq, first, rest, header_len, mac):
        """Verify the signature of and decrypt an SSH packet"""

        raise NotImplementedError


class BasicEncryption(Encryption):
    """Shim for basic encryption"""

    def __init__(self, cipher, mac):
        self._cipher = cipher
        self._mac = mac

    @classmethod
    def new(cls, cipher_name, key, iv, mac_alg=b'', mac_key=b'', etm=False):
        """Construct a new SSH packet encryption object for basic ciphers"""

        cipher = BasicCipher(cipher_name, key, iv)
        mac = get_mac(mac_alg, mac_key)

        if etm:
            return ETMEncryption(cipher, mac)
        else:
            return cls(cipher, mac)

    def encrypt_packet(self, seq, header, packet):
        """Encrypt and sign an SSH packet"""

        packet = header + packet
        mac = self._mac.sign(seq, packet) if self._mac else b''

        return self._cipher.encrypt(packet), mac

    def decrypt_header(self, seq, first_block, header_len):
        """Decrypt an SSH packet header"""

        first_block = self._cipher.decrypt(first_block)

        return first_block, first_block[:header_len]

    def decrypt_packet(self, seq, first, rest, header_len, mac):
        """Verify the signature of and decrypt an SSH packet"""

        packet = first + self._cipher.decrypt(rest)

        if self._mac.verify(seq, packet, mac):
            return packet[header_len:]
        else:
            return None


class ETMEncryption(BasicEncryption):
    """Shim for encrypt-then-mac encryption"""

    def encrypt_packet(self, seq, header, packet):
        """Encrypt and sign an SSH packet"""

        packet = header + self._cipher.encrypt(packet)
        return packet, self._mac.sign(seq, packet)

    def decrypt_header(self, seq, first_block, header_len):
        """Decrypt an SSH packet header"""

        return first_block, first_block[:header_len]

    def decrypt_packet(self, seq, first, rest, header_len, mac):
        """Verify the signature of and decrypt an SSH packet"""

        packet = first + rest

        if self._mac.verify(seq, packet, mac):
            return self._cipher.decrypt(packet[header_len:])
        else:
            return None


class GCMEncryption(Encryption):
    """Shim for GCM encryption"""

    def __init__(self, cipher):
        self._cipher = cipher

    @classmethod
    def new(cls, cipher_name, key, iv, mac_alg=b'', mac_key=b'', etm=False):
        """Construct a new SSH packet encryption object for GCM ciphers"""

        return cls(GCMCipher(cipher_name, key, iv))

    @classmethod
    def get_mac_params(cls, mac_alg):
        """Get paramaters of the MAC algorithm used with this encryption"""

        return 0, 16, True

    def encrypt_packet(self, seq, header, packet):
        """Encrypt and sign an SSH packet"""

        return self._cipher.encrypt_and_sign(header, packet)

    def decrypt_header(self, seq, first_block, header_len):
        """Decrypt an SSH packet header"""

        return first_block, first_block[:header_len]

    def decrypt_packet(self, seq, first, rest, header_len, mac):
        """Verify the signature of and decrypt an SSH packet"""

        return self._cipher.verify_and_decrypt(first[:header_len],
                                               first[header_len:] + rest, mac)


class ChachaEncryption(Encryption):
    """Shim for chacha20-poly1305 encryption"""

    def __init__(self, cipher):
        self._cipher = cipher

    @classmethod
    def new(cls, cipher_name, key, iv, mac_alg=b'', mac_key=b'', etm=False):
        """Construct a new SSH packet encryption object for Chacha ciphers"""

        return cls(ChachaCipher(key))

    @classmethod
    def get_mac_params(cls, mac_alg):
        """Get paramaters of the MAC algorithm used with this encryption"""

        return 0, 16, True

    def encrypt_packet(self, seq, header, packet):
        """Encrypt and sign an SSH packet"""

        return self._cipher.encrypt_and_sign(header, packet, UInt64(seq))

    def decrypt_header(self, seq, first_block, header_len):
        """Decrypt an SSH packet header"""

        return (first_block,
                self._cipher.decrypt_header(first_block[:header_len],
                                            UInt64(seq)))

    def decrypt_packet(self, seq, first, rest, header_len, mac):
        """Verify the signature of and decrypt an SSH packet"""

        return self._cipher.verify_and_decrypt(first[:header_len],
                                               first[header_len:] + rest,
                                               UInt64(seq), mac)


def register_encryption_alg(enc_alg, encryption, cipher_name):
    """Register an encryption algorithm"""

    try:
        get_cipher_params(cipher_name)
    except KeyError:
        pass
    else:
        _enc_algs.append(enc_alg)
        _enc_params[enc_alg] = (encryption, cipher_name)


def get_encryption_algs():
    """Return a list of available encryption algorithms"""

    return _enc_algs


def get_encryption_params(enc_alg, mac_alg=b''):
    """Get parameters of an encryption and MAC algorithm"""

    encryption, cipher_name = _enc_params[enc_alg]
    enc_keysize, enc_ivsize, enc_blocksize = get_cipher_params(cipher_name)
    mac_keysize, mac_hashsize, etm = encryption.get_mac_params(mac_alg)

    return (enc_keysize, enc_ivsize, enc_blocksize,
            mac_keysize, mac_hashsize, etm)


def get_encryption(enc_alg, key, iv, mac_alg=b'', mac_key=b'', etm=False):
    """Return an object which can encrypt and decrypt SSH packets"""

    encryption, cipher_name = _enc_params[enc_alg]

    return encryption.new(cipher_name, key, iv, mac_alg, mac_key, etm)


# pylint: disable=bad-whitespace

_enc_alg_list = (
    (b'chacha20-poly1305@openssh.com', ChachaEncryption, 'chacha20-poly1305'),
    (b'aes256-gcm@openssh.com',        GCMEncryption,    'aes256-gcm'),
    (b'aes128-gcm@openssh.com',        GCMEncryption,    'aes128-gcm'),
    (b'aes256-ctr',                    BasicEncryption,  'aes256-ctr'),
    (b'aes192-ctr',                    BasicEncryption,  'aes192-ctr'),
    (b'aes128-ctr',                    BasicEncryption,  'aes128-ctr'),
    (b'aes256-cbc',                    BasicEncryption,  'aes256-cbc'),
    (b'aes192-cbc',                    BasicEncryption,  'aes192-cbc'),
    (b'aes128-cbc',                    BasicEncryption,  'aes128-cbc'),
    (b'3des-cbc',                      BasicEncryption,  'des3-cbc'),
    (b'blowfish-cbc',                  BasicEncryption,  'blowfish-cbc'),
    (b'cast128-cbc',                   BasicEncryption,  'cast128-cbc'),
    (b'arcfour256',                    BasicEncryption,  'arcfour256'),
    (b'arcfour128',                    BasicEncryption,  'arcfour128'),
    (b'arcfour',                       BasicEncryption,  'arcfour')
)

for _enc_alg_args in _enc_alg_list:
    register_encryption_alg(*_enc_alg_args)
