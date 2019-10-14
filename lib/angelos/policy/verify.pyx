# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Verify entities by issuing statements."""
from .policy import Policy
from .crypto import Crypto
from .portfolio import Portfolio, PrivatePortfolio
from ..document import Verified, Trusted, Revoked, Statement


class StatementPolicy(Policy):
    """Policy for issuing statements."""

    @staticmethod
    def verified(issuer: PrivatePortfolio, owner: Portfolio) -> Verified:
        """Issue a verified statement."""

        verified = Verified(
            nd={"issuer": issuer.entity.id, "owner": owner.entity.id}
        )

        verified = Crypto.sign(verified, issuer)
        verified.validate()

        issuer.issuer.verified.add(verified)
        owner.owner.verified.add(verified)

        return verified

    @staticmethod
    def trusted(issuer: PrivatePortfolio, owner: Portfolio) -> Trusted:
        """Issue a trusted statement."""

        trusted = Trusted(
            nd={"issuer": issuer.entity.id, "owner": owner.entity.id}
        )

        trusted = Crypto.sign(trusted, issuer)
        trusted.validate()

        issuer.issuer.trusted.add(trusted)
        owner.owner.trusted.add(trusted)

        return trusted

    @staticmethod
    def revoked(issuer: PrivatePortfolio, statement: Statement) -> Revoked:
        """Revoke earlier statement."""

        if isinstance(statement, Revoked):
            return False

        revoked = Revoked(
            nd={"issuer": issuer.entity.id, "issuance": statement.id}
        )

        revoked = Crypto.sign(revoked, issuer)
        revoked.validate()
        issuer.issuer.revoked.add(revoked)

        return revoked

    @staticmethod
    def validate_verified(
        issuer: PrivatePortfolio, owner: Portfolio
    ) -> Verified:
        """Validate that the owners verification is valid. Return document"""
        valid_verified = None
        for verified in issuer.issuer.verified | owner.owner.verified:
            if (
                verified.owner == owner.entity.id
            ) and verified.issuer == issuer.entity.id:
                try:
                    valid = True
                    valid = verified.validate() if valid else valid
                    valid = Crypto.verify(verified, issuer) if valid else valid
                except Exception:
                    valid = False
                if valid:
                    valid_verified = verified

        return valid_verified

    @staticmethod
    def validate_trusted(
        issuer: PrivatePortfolio, owner: Portfolio
    ) -> Trusted:
        """Validate that the owners trustedness is valid. Return document."""
        valid_trusted = None
        for trusted in issuer.issuer.trusted | owner.owner.trusted:
            if (
                trusted.owner == owner.entity.id
            ) and trusted.issuer == issuer.entity.id:
                try:
                    valid = True
                    valid = trusted.validate() if valid else valid
                    valid = Crypto.verify(trusted, issuer) if valid else valid
                except Exception:
                    valid = False
                if valid:
                    valid_trusted = trusted

        return valid_trusted
