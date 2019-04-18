"""Module docstring."""
import base64

import libnacl.sign
import asyncssh

from asyncssh.public_key import register_public_key_alg

from ..utils import Util

_algorithm = b'angelos-tongues'


class BaseKey:
    """Base class for private/public keys"""

    def __init__(self, key, box):
        self._key = key
        self._box = box

    @property
    def key(self):
        return self._key


class NaClPrivateKey(BaseKey):
    @classmethod
    def construct(cls, seed):
        """Construct an NaCl private key"""
        Util.is_type(seed, bytes)
        box = libnacl.sign.Signer(seed)

        return cls(box.seed, box)

    @classmethod
    def generate(cls):
        """Generate a new NaCl private key"""
        box = libnacl.sign.Signer()

        return cls(box.seed, box)

    def sign(self, data):
        """Sign a block of data"""
        return self._box.signature(data)

    @property
    def value(self):
        return self._box.vk


class NaClPublicKey(BaseKey):
    @classmethod
    def construct(cls, verify):
        """Construct an NaCl public key"""
        Util.is_type(verify, bytes)
        box = libnacl.sign.Verifier(verify.hex())

        return cls(verify, box)

    def verify(self, data, sig):
        """Verify the signature on a block of data"""
        try:
            self._box.verify(sig + data)
            return True
        except ValueError:
            return False

    @property
    def value(self):
        return self._box.vk


class NaClKey(asyncssh.SSHKey):
    def __init__(self, key):
        super().__init__(key)
        self.algorithm = _algorithm
        self.sig_algorithms = (self.algorithm,)
        self.all_sig_algorithms = set(self.sig_algorithms)

    def sign_der(self, data, sig_algorithm):
        """Abstract method to compute a DER-encoded signature"""
        if not self._key.key:
            raise ValueError('Private key needed for signing')

        return self._key.sign(data)

    def verify_der(self, data, sig_algorithm, sig):
        """Abstract method to verify a DER-encoded signature"""
        return self._key.verify(data, sig)

    def sign_ssh(self, data, sig_algorithm):
        """Abstract method to compute an SSH-encoded signature"""
        return self.sign_der(data, sig_algorithm)

    def verify_ssh(self, data, sig_algorithm, sig):
        """Abstract method to verify an SSH-encoded signature"""
        return self.verify_der(data, sig_algorithm, sig)

    def encode_ssh_private(self):
        return base64.b64encode(self._key.value)

    def encode_ssh_public(self):
        return base64.b64encode(self._key.value)

    @classmethod
    def decode_ssh_public(cls, packet):
        public_value = base64.b64decode(
            packet.get_bytes(packet._len - packet._idx))
        return (public_value,)

    @classmethod
    def decode_ssh_private(cls, packet):
        private_value = base64.b64decode(
            packet.get_bytes(packet._len - packet._idx))
        return (private_value,)

    @classmethod
    def make_private(cls, private_value):
        return cls(NaClPrivateKey.construct(private_value))

    @classmethod
    def make_public(cls, public_value):
        return cls(NaClPublicKey.construct(public_value))

    def __eq__(self, other):
        return (isinstance(other, type(self)) and
                self._key.value == other._key.value)

    def __hash__(self):
        return hash((self.algorithm, self._key.value))

    # def validate(self, key, address):
    #    print('Validate?')


register_public_key_alg(_algorithm, NaClKey, (_algorithm,))


def make_known_hosts(verify):
    return lambda h, a, p: (
        [NaClKey(key=NaClPublicKey.construct(verify=verify))], [], [])
