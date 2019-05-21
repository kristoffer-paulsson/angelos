# cython: language_level=3
"""Verify entities by issuing statements."""
from ..utils import Util
from .policy import SignPolicy
from .crypto import Crypto
from ..document.entities import Person, Ministry, Church
from ..document.statements import Verified, Trusted, Revoked


class StatementPolicy(SignPolicy):
    """Policy for issuing statements."""

    def __init__(self, **kwargs):
        SignPolicy.__init__(self, **kwargs)
        self.statement = None

    def verified(self, entity):
        """Issue a verified statement."""
        Util.is_type(entity, (Person, Ministry, Church))

        new_stat = Verified(nd={
            'issuer': self.entity.id,
            'owner': entity.id
        })

        new_stat = Crypto.sign(new_stat, self.entity, self.privkeys, self.keys)
        new_stat.validate()

        self.statement = new_stat
        return True

    def trusted(self, entity):
        """Issue a trusted statement."""
        Util.is_type(entity, (Person, Ministry, Church))

        new_stat = Trusted(nd={
            'issuer': self.entity.id,
            'owner': entity.id
        })

        new_stat = Crypto.sign(new_stat, self.entity, self.privkeys, self.keys)
        new_stat.validate()

        self.statement = new_stat
        return True

    def revoked(self, statement):
        """Revoke earlier statement."""
        Util.is_type(statement, (Verified, Trusted))

        new_stat = Revoked(nd={
            'issuer': self.entity.id,
            'issuance': statement.id
        })

        new_stat = Crypto.sign(new_stat, self.entity, self.privkeys, self.keys)
        new_stat.validate()

        self.statement = new_stat
        return True
