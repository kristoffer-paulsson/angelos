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
"""Encoding of Base64 and binary <-> hexadecimal backed by libsodium."""
from angelos.bin.nacl import sodium_bin2base64, sodium_base642bin, sodium_base64_encoded_len, BASE64_VARIANT_URLSAFE


class Base64:
    """Base64 codec."""

    @classmethod
    def encode(cls, binary: bytes) -> bytes:
        pass
        # length = sodium_base64_encoded_len(len(binary), BASE64_VARIANT_URLSAFE)
        # base64 = bytes(length)
        # sodium_base642bin(base64, length, binary, len(binary), BASE64_VARIANT_URLSAFE)

    @classmethod
    def decode(cls, base64: bytes) -> bytes:
        pass
        # sodium_bin2base64()
        # sodium_base64_encoded_len()