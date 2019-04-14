# Copyright (c) 2019 by Ron Frederick <ronf@timeheart.net> and others.
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

"""EdDSA public key encryption handler"""

from .asn1 import ASN1DecodeError, ObjectIdentifier, der_encode, der_decode
from .crypto import EdDSAPrivateKey, EdDSAPublicKey
from .packet import String
from .public_key import OMIT, SSHKey, SSHOpenSSHCertificateV01
from .public_key import KeyImportError, KeyExportError
from .public_key import register_public_key_alg, register_certificate_alg


class _EdKey(SSHKey):
    """Handler for EdDSA public key encryption"""

    algorithm = b''

    def __eq__(self, other):
        # This isn't protected access - both objects are _EdKey instances
        # pylint: disable=protected-access

        return (isinstance(other, type(self)) and
                self._key.public_value == other._key.public_value and
                self._key.private_value == other._key.private_value)

    def __hash__(self):
        return hash((self._key.public_value, self._key.private_value))

    @classmethod
    def generate(cls, algorithm):
        """Generate a new EdDSA private key"""

        # Strip 'ssh-' prefix of algorithm to get curve_id
        return cls(EdDSAPrivateKey.generate(algorithm[4:]))

    @classmethod
    def make_private(cls, private_value):
        """Construct an EdDSA private key"""

        try:
            return cls(EdDSAPrivateKey.construct(cls.algorithm[4:],
                                                 private_value))
        except (TypeError, ValueError):
            raise KeyImportError('Invalid EdDSA private key') from None

    @classmethod
    def make_public(cls, public_value):
        """Construct an EdDSA public key"""

        try:
            return cls(EdDSAPublicKey.construct(cls.algorithm[4:],
                                                public_value))
        except (TypeError, ValueError):
            raise KeyImportError('Invalid EdDSA public key') from None

    @classmethod
    def decode_pkcs8_private(cls, alg_params, data):
        """Decode a PKCS#8 format EdDSA private key"""

        # pylint: disable=unused-argument

        try:
            return (der_decode(data),)
        except ASN1DecodeError:
            return None

    @classmethod
    def decode_pkcs8_public(cls, alg_params, key_data):
        """Decode a PKCS#8 format EdDSA public key"""

        # pylint: disable=unused-argument

        return (key_data,)

    @classmethod
    def decode_ssh_private(cls, packet):
        """Decode an SSH format EdDSA private key"""

        public_value = packet.get_string()
        private_value = packet.get_string()

        return (private_value[:-len(public_value)],)

    @classmethod
    def decode_ssh_public(cls, packet):
        """Decode an SSH format EdDSA public key"""

        public_value = packet.get_string()

        return (public_value,)

    def encode_pkcs8_private(self):
        """Encode a PKCS#8 format EdDSA private key"""

        if not self._key.private_value:
            raise KeyExportError('Key is not private')

        return OMIT, der_encode(self._key.private_value)

    def encode_pkcs8_public(self):
        """Encode a PKCS#8 format EdDSA public key"""

        return OMIT, self._key.public_value

    def encode_ssh_private(self):
        """Encode an SSH format EdDSA private key"""

        if self._key.private_value is None:
            raise KeyExportError('Key is not private')

        return b''.join((String(self._key.public_value),
                         String(self._key.private_value +
                                self._key.public_value)))

    def encode_ssh_public(self):
        """Encode an SSH format EdDSA public key"""

        return String(self._key.public_value)

    def encode_agent_cert_private(self):
        """Encode EdDSA certificate private key data for agent"""

        return self.encode_ssh_private()

    def sign_der(self, data, sig_algorithm):
        """Compute a DER-encoded signature of the specified data"""

        # pylint: disable=unused-argument

        if not self._key.private_value:
            raise ValueError('Private key needed for signing')

        return self._key.sign(data)

    def verify_der(self, data, sig_algorithm, sig):
        """Verify a DER-encoded signature of the specified data"""

        # pylint: disable=unused-argument

        return self._key.verify(data, sig)

    def sign_ssh(self, data, sig_algorithm):
        """Compute an SSH-encoded signature of the specified data"""

        return self.sign_der(data, sig_algorithm)

    def verify_ssh(self, data, sig_algorithm, sig):
        """Verify an SSH-encoded signature of the specified data"""

        return self.verify_der(data, sig_algorithm, sig)


class _Ed25519Key(_EdKey):
    """Handler for Curve25519 public key encryption"""

    algorithm = b'ssh-ed25519'
    pkcs8_oid = ObjectIdentifier('1.3.101.112')
    sig_algorithms = (algorithm,)
    all_sig_algorithms = set(sig_algorithms)


class _Ed448Key(_EdKey):
    """Handler for Curve448 public key encryption"""

    algorithm = b'ssh-ed448'
    pkcs8_oid = ObjectIdentifier('1.3.101.113')
    sig_algorithms = (algorithm,)
    all_sig_algorithms = set(sig_algorithms)


for _cls in (_Ed25519Key, _Ed448Key):
    _cert_algorithm = _cls.algorithm + b'-cert-v01@openssh.com'

    register_public_key_alg(_cls.algorithm, _cls)

    register_certificate_alg(1, _cls.algorithm, _cert_algorithm,
                             _cls, SSHOpenSSHCertificateV01)
