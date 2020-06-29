# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import base64
import asyncssh

from asyncssh.public_key import register_public_key_alg
from libangelos.library.nacl import Signer, Verifier

from libangelos.utils import Util

_algorithm = b"angelos-tongues"


class BaseKey:
    """Base class for private/public keys."""

    def __init__(self, key, box):
        """Set the key and box properties."""
        self._key = key
        self._box = box

    @property
    def key(self):
        """Key property."""
        return self._key


class NaClPrivateKey(BaseKey):
    """Private key based on NaCl for asyncssh."""

    @classmethod
    def construct(cls, seed):
        """Construct an NaCl public key."""
        Util.is_type(seed, bytes)
        box = Signer(seed)

        return cls(box.seed, box)

    @classmethod
    def generate(cls):
        """Generate a new NaCl private key."""
        box = Signer()

        return cls(box.seed, box)

    def sign(self, data):
        """Sign a block of data."""
        return self._box.signature(data)

    @property
    def value(self):
        """Verification key."""
        return self._box.vk


class NaClPublicKey(BaseKey):
    """Public key based on NaCl for asyncssh."""

    @classmethod
    def construct(cls, verify):
        """Construct an NaCl public key."""
        Util.is_type(verify, bytes)
        box = Verifier(verify)

        return cls(verify, box)

    def verify(self, data, sig):
        """Verify the signature on a block of data."""
        try:
            #print(data, type(data), sig, type(sig))
            self._box.verify(sig.get_remaining_payload() + data)
            return True
        except ValueError:
            return False

    @property
    def value(self):
        """Verification key."""
        return self._box.vk


class NaClKey(asyncssh.SSHKey):
    """SSHKey for NaCl."""

    def __init__(self, key):
        """Initialize key."""
        super().__init__(key)
        self.algorithm = _algorithm
        self.sig_algorithms = (self.algorithm,)
        self.all_sig_algorithms = set(self.sig_algorithms)

    def sign_der(self, data, sig_algorithm):
        """Abstract method to compute a DER-encoded signature."""
        if not self._key.key:
            raise ValueError("Private key needed for signing")

        return self._key.sign(data)

    def verify_der(self, data, sig_algorithm, sig):
        """Abstract method to verify a DER-encoded signature."""
        return self._key.verify(data, sig)

    def sign_ssh(self, data, sig_algorithm):
        """Abstract method to compute an SSH-encoded signature."""
        return self.sign_der(data, sig_algorithm)

    def verify_ssh(self, data, sig_algorithm, sig):
        """Abstract method to verify an SSH-encoded signature."""
        return self.verify_der(data, sig_algorithm, sig)

    def encode_ssh_private(self):
        """Encode private SSH key."""
        return base64.b64encode(self._key.value)

    def encode_ssh_public(self):
        """Encode public SSH key."""
        return base64.b64encode(self._key.value)

    @classmethod
    def decode_ssh_public(cls, packet):
        """Decode public SSH key."""
        public_value = base64.b64decode(
            packet.get_bytes(packet._len - packet._idx)
        )
        return (public_value,)

    @classmethod
    def decode_ssh_private(cls, packet):
        """Decode private SSH key."""
        private_value = base64.b64decode(
            packet.get_bytes(packet._len - packet._idx)
        )
        return (private_value,)

    @classmethod
    def make_private(cls, private_value):
        """Produce a private NaCl key."""
        return cls(NaClPrivateKey.construct(private_value))

    @classmethod
    def make_public(cls, public_value):
        """Produce a public SSH key."""
        return cls(NaClPublicKey.construct(public_value))

    def __eq__(self, other):
        """Compare class with another object."""
        return (
            isinstance(other, type(self))
            and self._key.value == other._key.value
        )

    def __hash__(self):
        """Generate a hash for this class."""
        return hash((self.algorithm, self._key.value))

    @staticmethod
    def factory(keys):
        return NaClKey(key=NaClPublicKey.construct(keys.verify))


register_public_key_alg(_algorithm, NaClKey, (_algorithm,))


def make_known_hosts(verify):
    """Produce a known hosts generator."""
    return lambda h, a, p: (
        [NaClKey(key=NaClPublicKey.construct(verify=verify))],
        [],
        [],
    )
