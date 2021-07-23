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
"""Print formatting strings."""
import uuid

from angelos.document.types import EntityT
from angelos.document.document import DocType
from angelos.lib.policy.portfolio import Portfolio


class PrintPolicy:
    """Format print strings."""

    POLICY = dict(A="1A", B="1B", C="2C", D="2D", E="2E", F="3F", G="3G", H="3H", J="3J", K="4K", L="4L", M="4M",
                   N="4N", P="5P", Q="5Q", R="5R", S="5S", T="6T", U="6U", V="6V", X="6X", Y="7Y", Z="7Z")


    @staticmethod
    def title(portfolio: Portfolio) -> str:
        """Format title and name based on entity type.

        Parameters
        ----------
        portfolio : Portfolio
            Portfolio belonging to entity.

        Returns
        -------
        str
            Formatted title string.

        """
        return PrintPolicy.entity_title(portfolio.entity)

    @staticmethod
    def entity_title(entity: EntityT) -> str:
        """Format an entitys title.

        Parameters
        ----------
        entity : Entity
            An entity document.

        Returns
        -------
        str
            Correctly formatted title string.

        """
        if entity.type == DocType.ENTITY_PERSON:
            initials = ""
            for name in entity.names[1:]:
                initials += name[:1].upper() + "."
            return "{0} {1} {2}".format(
                entity.given_name, initials, entity.family_name
            )
        elif entity.type == DocType.ENTITY_MINISTRY:
            return "{0}".format(entity.ministry)
        elif entity.type == DocType.ENTITY_CHURCH:
            name = "City church of {0}".format(entity.city)
            if entity.region:
                name += ", {0}".format(entity.region)
            if entity.country:
                name += ", {0}".format(entity.country)
            return name

        return "n/a"

    @staticmethod
    def policy(p: tuple, compact: bool=True) -> str:
        """Print a policy"""
        if not p[0] or compact:
            return "{1}-{2:0>4}".format(PrintPolicy.POLICY[p[1]] if p[1] in PrintPolicy.POLICY else "0I", p[2])
        else:
            return "{1}-{2:0>4}:{0!s}".format(
                uuid.UUID(p[0]), PrintPolicy.POLICY[p[1]] if p[1] in PrintPolicy.POLICY else "0I", p[2])
