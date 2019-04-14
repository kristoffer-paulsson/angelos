# Copyright (c) 2015-2018 by Ron Frederick <ronf@timeheart.net> and others.
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

"""A shim around PyCA for elliptic curve keys and key exchange"""

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.backends.openssl import backend
from cryptography.hazmat.primitives.hashes import SHA256, SHA384, SHA512
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import Encoding
from cryptography.hazmat.primitives.serialization import PublicFormat

from .misc import PyCAKey


# Short variable names are used here, matching names in the spec
# pylint: disable=invalid-name

_curves = {b'1.3.132.0.10': (ec.SECP256K1, SHA256),
           b'nistp256':     (ec.SECP256R1, SHA256),
           b'nistp384':     (ec.SECP384R1, SHA384),
           b'nistp521':     (ec.SECP521R1, SHA512)}


class _ECKey(PyCAKey):
    """Base class for shim around PyCA for EC keys"""

    def __init__(self, pyca_key, curve_id, hash_alg, pub, point, priv=None):
        super().__init__(pyca_key)

        self._curve_id = curve_id
        self._hash_alg = hash_alg
        self._pub = pub
        self._point = point
        self._priv = priv

    @classmethod
    def lookup_curve(cls, curve_id):
        """Look up curve and hash algorithm"""

        try:
            return _curves[curve_id]
        except KeyError: # pragma: no cover, other curves not registered
            raise ValueError('Unknown EC curve %s' %
                             curve_id.decode()) from None

    @property
    def curve_id(self):
        """Return the EC curve name"""

        return self._curve_id

    @property
    def x(self):
        """Return the EC public x coordinate"""

        return self._pub.x

    @property
    def y(self):
        """Return the EC public y coordinate"""

        return self._pub.y

    @property
    def d(self):
        """Return the EC private value as an integer"""

        return self._priv.private_value if self._priv else None

    @property
    def public_value(self):
        """Return the EC public point value encoded as a byte string"""

        return self._point

    @property
    def private_value(self):
        """Return the EC private value encoded as a byte string"""

        if self._priv:
            keylen = (self._pub.curve.key_size + 7) // 8
            return self._priv.private_value.to_bytes(keylen, 'big')
        else:
            return None


class ECDSAPrivateKey(_ECKey):
    """A shim around PyCA for ECDSA private keys"""

    @classmethod
    def construct(cls, curve_id, public_value, private_value):
        """Construct an ECDSA private key"""

        curve, hash_alg = cls.lookup_curve(curve_id)

        priv_key = ec.derive_private_key(private_value, curve(), backend)
        priv = priv_key.private_numbers()
        pub = priv.public_numbers

        return cls(priv_key, curve_id, hash_alg, pub, public_value, priv)

    @classmethod
    def generate(cls, curve_id):
        """Generate a new ECDSA private key"""

        curve, hash_alg = cls.lookup_curve(curve_id)

        priv_key = ec.generate_private_key(curve(), backend)
        priv = priv_key.private_numbers()

        pub_key = priv_key.public_key()
        pub = pub_key.public_numbers()

        public_value = pub_key.public_bytes(Encoding.X962,
                                            PublicFormat.UncompressedPoint)

        return cls(priv_key, curve_id, hash_alg, pub, public_value, priv)

    def sign(self, data):
        """Sign a block of data"""

        priv_key = self.pyca_key
        return priv_key.sign(data, ec.ECDSA(self._hash_alg()))


class ECDSAPublicKey(_ECKey):
    """A shim around PyCA for ECDSA public keys"""

    @classmethod
    def construct(cls, curve_id, public_value):
        """Construct an ECDSA public key"""

        curve, hash_alg = cls.lookup_curve(curve_id)

        pub_key = ec.EllipticCurvePublicKey.from_encoded_point(curve(),
                                                               public_value)
        pub = pub_key.public_numbers()

        return cls(pub_key, curve_id, hash_alg, pub, public_value)

    def verify(self, data, sig):
        """Verify the signature on a block of data"""

        try:
            pub_key = self.pyca_key
            pub_key.verify(sig, data, ec.ECDSA(self._hash_alg()))
            return True
        except InvalidSignature:
            return False


class ECDH:
    """A shim around PyCA for ECDH key exchange"""

    def __init__(self, curve_id):
        try:
            curve, _ = _curves[curve_id]
        except KeyError: # pragma: no cover, other curves not registered
            raise ValueError('Unknown EC curve %s' %
                             curve_id.decode()) from None

        self._priv_key = ec.generate_private_key(curve(), backend)

    def get_public(self):
        """Return the public key to send in the handshake"""

        pub_key = self._priv_key.public_key()

        return pub_key.public_bytes(Encoding.X962,
                                    PublicFormat.UncompressedPoint)

    def get_shared(self, peer_public):
        """Return the shared key from the peer's public key"""

        peer_key = ec.EllipticCurvePublicKey.from_encoded_point(
            self._priv_key.curve, peer_public)

        shared_key = self._priv_key.exchange(ec.ECDH(), peer_key)

        return int.from_bytes(shared_key, 'big')
