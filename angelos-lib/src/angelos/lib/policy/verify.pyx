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
"""Verify entities by issuing statements."""
from angelos.lib.policy.policy import Policy
from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.portfolio import Portfolio, PrivatePortfolio
from angelos.document.types import StatementT
from angelos.document.statements import Verified, Trusted, Revoked


class StatementPolicy(Policy):
    """Policy for issuing statements."""

    @staticmethod
    def verified(issuer: PrivatePortfolio, owner: Portfolio) -> Verified:
        """Issue a verified statement.

        Args:
            issuer (PrivatePortfolio):
                The issuer portfolio
            owner (Portfolio):
                The subject portfolio

        Returns (Verified):
            The verified statement

        """

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
        """Issue a trusted statement.

        Args:
            issuer (PrivatePortfolio):
                The issuer portfolio
            owner (Portfolio):
                The subject portfolio

        Returns (Trusted):
            The trusted statement

        """

        trusted = Trusted(
            nd={"issuer": issuer.entity.id, "owner": owner.entity.id}
        )

        trusted = Crypto.sign(trusted, issuer)
        trusted.validate()

        issuer.issuer.trusted.add(trusted)
        owner.owner.trusted.add(trusted)

        return trusted

    @staticmethod
    def revoked(issuer: PrivatePortfolio, statement: StatementT) -> Revoked:
        """Revoke earlier statement.

        Args:
            issuer (PrivatePortfolio):
                The issuer portfolio
            statement (StatementT):
                statement that is subject for revoke

        Returns (Revoked):
            The revoking statement

        """

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

                valid = True
                valid = verified.validate() if valid else valid
                valid = Crypto.verify(verified, issuer) if valid else valid

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

                valid = True
                valid = trusted.validate() if valid else valid
                valid = Crypto.verify(trusted, issuer) if valid else valid

                if valid:
                    valid_trusted = trusted

        return valid_trusted
