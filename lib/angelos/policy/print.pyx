# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Print formatting strings."""
from ..document import DocType, Entity
from .portfolio import Portfolio


class PrintPolicy:
    """Format print strings."""

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
    def entity_title(entity: Entity) -> str:
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
