# cython: language_level=3
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
"""Helper utilities for portfolios."""
import datetime
import uuid
from pathlib import PurePosixPath
from typing import Tuple

from angelos.document.document import Document
from angelos.document.domain import Domain, Node, Network
from angelos.document.entities import Person, Ministry, Church, PrivateKeys, Keys
from angelos.document.profiles import PersonProfile, MinistryProfile, ChurchProfile
from angelos.document.statements import Verified, Trusted, Revoked


class Fields:
    """Portfolio field naming."""

    ENTITY = "entity"
    PROFILE = "profile"
    PRIVKEYS = "privkeys"
    KEYS = "keys"
    DOMAIN = "domain"
    NODE = "node"
    NODES = "nodes"
    NET = "network"

    ISSUER_VERIFIED = "issuer_verified"
    ISSUER_TRUSTED = "issuer_trusted"
    ISSUER_REVOKED = "issuer_revoked"

    OWNER_VERIFIED = "owner_verified"
    OWNER_TRUSTED = "owner_trusted"
    OWNER_REVOKED = "owner_revoked"


class Groups:
    """Portfolio field configuration groups."""

    # Basic set for verifying documents
    VERIFIER = (Fields.ENTITY, Fields.KEYS)
    # Set for verifying documents and check revoked documents
    VERIFIER_REVOKED = (Fields.ENTITY, Fields.KEYS, Fields.ISSUER_REVOKED)
    # Basic set for signing documents
    SIGNER = (Fields.ENTITY, Fields.PRIVKEYS, Fields.KEYS)
    # Basic set for running Client Facade
    CLIENT = (
        Fields.ENTITY,
        Fields.PRIVKEYS,
        Fields.KEYS,
        Fields.DOMAIN,
        Fields.NODES,
    )
    # Basic set for running Server Facade
    SERVER = (
        Fields.ENTITY,
        Fields.PRIVKEYS,
        Fields.KEYS,
        Fields.DOMAIN,
        Fields.NODES,
        Fields.NET,
    )
    # Necessary set for server authentication
    CLIENT_AUTH = (
        Fields.ENTITY,
        Fields.KEYS,
        Fields.NET,
        Fields.OWNER_VERIFIED,
        Fields.OWNER_TRUSTED,
    )
    # Documents issued by issuer
    ISSUER = (
        Fields.ISSUER_VERIFIED,
        Fields.ISSUER_TRUSTED,
        Fields.ISSUER_REVOKED,
    )
    # Documents issued by others
    OWNER = (Fields.OWNER_VERIFIED, Fields.OWNER_TRUSTED, Fields.OWNER_REVOKED)
    # Minimum set for sharing identity
    SHARE_MIN_USER = (Fields.ENTITY, Fields.KEYS)
    # Minimum set for sharing community
    SHARE_MIN_COMMUNITY = (Fields.ENTITY, Fields.KEYS, Fields.NET)
    # Medium set for sharing identity
    SHARE_MED_USER = (Fields.ENTITY, Fields.PROFILE, Fields.KEYS)
    # Medium set for sharing community
    SHARE_MED_COMMUNITY = (
        Fields.ENTITY,
        Fields.PROFILE,
        Fields.KEYS,
        Fields.NET,
    )
    # Maximum set for sharing identity
    SHARE_MAX_USER = (
        Fields.ENTITY,
        Fields.PROFILE,
        Fields.KEYS,
        Fields.OWNER_VERIFIED,
        Fields.OWNER_TRUSTED,
    )
    # Maximum set for sharing community
    SHARE_MAX_COMMUNITY = (
        Fields.ENTITY,
        Fields.PROFILE,
        Fields.KEYS,
        Fields.NET,
        Fields.OWNER_VERIFIED,
        Fields.OWNER_TRUSTED,
    )
    # Complete set of documents of all types
    ALL = (
        Fields.ENTITY,
        Fields.PROFILE,
        Fields.PRIVKEYS,
        Fields.KEYS,
        Fields.DOMAIN,
        Fields.NODE,
        Fields.NODES,
        Fields.NET,
        Fields.ISSUER_VERIFIED,
        Fields.ISSUER_TRUSTED,
        Fields.ISSUER_REVOKED,
        Fields.OWNER_VERIFIED,
        Fields.OWNER_TRUSTED,
        Fields.OWNER_REVOKED,
    )


class Definitions:
    """Definitions for portfolios."""

    EXTENSION = {
        Fields.ENTITY: ".ent",
        Fields.PROFILE: ".pfl",
        Fields.PRIVKEYS: ".pky",
        Fields.KEYS: ".key",
        Fields.DOMAIN: ".dmn",
        Fields.NODES: ".nod",
        Fields.NODE: ".nod",
        Fields.NET: ".net",
        Fields.ISSUER_VERIFIED: ".ver",
        Fields.ISSUER_TRUSTED: ".rst",
        Fields.ISSUER_REVOKED: ".rev",
        Fields.OWNER_VERIFIED: ".ver",
        Fields.OWNER_TRUSTED: ".rst",
        Fields.OWNER_REVOKED: ".rev",
    }

    TYPES = {
        Fields.ENTITY: (Person, Ministry, Church),
        Fields.PROFILE: (PersonProfile, MinistryProfile, ChurchProfile),
        Fields.PRIVKEYS: (PrivateKeys, ),
        Fields.KEYS: (Keys, ),
        Fields.DOMAIN: (Domain, ),
        Fields.NODES: (Node, ),
        Fields.NODE: (Node, ),
        Fields.NET: (Network, ),
        Fields.ISSUER_VERIFIED: (Verified, ),
        Fields.ISSUER_TRUSTED: (Trusted, ),
        Fields.ISSUER_REVOKED: (Revoked, ),
        Fields.OWNER_VERIFIED: (Verified, ),
        Fields.OWNER_TRUSTED: (Trusted, ),
        Fields.OWNER_REVOKED: (Revoked, ),
    }


class Helper:
    """Portfolio helper utility."""

    PATH = PurePosixPath("/portfolios/")

    @classmethod
    def document_meta(cls, document: Document) -> Tuple[datetime.datetime, datetime.datetime, uuid.UUID]:
        """Calculates the correct meta information about a document to be updated

        Args:
            document (Document):
                Enter a valid Document.

        Returns (datetime.datetime, datetime.datetime, uuid.UUID):
            Correct meta-data (created datetime, touched datetime, owner).

        """
        return datetime.datetime.combine(
            document.created, datetime.datetime.min.time()), datetime.datetime.combine(
            document.get_touched(), datetime.datetime.min.time()), document.get_owner()