# cython: language_level=3
"""Verify entities by issuing statements."""
from .policy import Policy
from .crypto import Crypto
from .portfolio import Portfolio, PrivatePortfolio
from ..document import Verified, Trusted, Revoked, Statement


class StatementPolicy(Policy):
    """Policy for issuing statements."""

    @staticmethod
    def verified(issuer: PrivatePortfolio, owner: Portfolio) -> bool:
        """Issue a verified statement."""

        verified = Verified(nd={
            'issuer': issuer.entity.id,
            'owner': owner.entity.id
        })

        verified = Crypto.sign(
            verified, issuer.entity, issuer.privkeys, next(iter(issuer.keys)))
        verified.validate()

        issuer.issuer.verified.add(verified)
        owner.owner.verified.add(verified)

        return True

    @staticmethod
    def trusted(issuer: PrivatePortfolio, owner: Portfolio) -> bool:
        """Issue a trusted statement."""

        trusted = Trusted(nd={
            'issuer': issuer.entity.id,
            'owner': owner.entity.id
        })

        trusted = Crypto.sign(
            trusted, issuer.entity, issuer.privkeys, next(iter(issuer.keys)))
        trusted.validate()

        issuer.issuer.trusted.add(trusted)
        owner.owner.trusted.add(trusted)

        return True

    @staticmethod
    def revoked(issuer: PrivatePortfolio, statement: Statement):
        """Revoke earlier statement."""

        if isinstance(statement, Revoked):
            return False

        revoked = Revoked(nd={
            'issuer': issuer.entity.id,
            'issuance': statement.id
        })

        revoked = Crypto.sign(
            revoked, issuer.entity, issuer.privkeys, next(iter(issuer.keys)))
        revoked.validate()

        return True
