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
from pathlib import PurePosixPath
from typing import Tuple

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


class MimeTypes:
    TEXT = "text/plain"
    MARKDOWN = "text/markdown"
    HTML = "text/html"
    RTF = "text/rtf"
    VCARD = "text/vcard"
    CALENDAR = "text/calendar"

    JPEG = "image/jpeg"
    WEBP = "image/webp"
    PNG = "image/png"
    TIFF = "image/tiff"
    BMP = "image/bmp"

    MP4_A = "audio/mp4"
    MPEG_A = "audio/mpeg"
    AAC = "audio/aac"
    WEBM = "audio/webm"
    VORBIS = "audio/vorbis"

    MP4 = "video/mp4"
    MPEG = "video/mpeg"
    QUICKTIME = "video/quicktime"
    H261 = "video/h261"
    H263 = "video/h263"
    H264 = "video/h264"
    H265 = "video/h265"
    OGG = "video/ogg"

    ZIP = "application/zip"
    _7Z = "application/x-7z-compressed"


class ReportType:
    UNSOLICITED = "Unsolicited"
    SPAM = "Spam"
    SUSPICIOUS = "Suspicious"
    HARMFUL = "Harmful"
    DEFAMATION = "Defamation"
    OFFENSIVE = "Offensive"
    HATEFUL = "Hateful"
    SEDITION = "Sedition"
    HARASSMENT = "Harassment"
    MENACE = "Menace"
    BLACKMAIL = "Blackmail"
    SOLICITATION = "Solicitation"
    CONSPIRACY = "Conspiracy"
    GRAPHIC = "Graphic"
    ADULT = "Adult"


class Definitions:
    """Definitions for portfolios."""

    SUFFIXES = {
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

    REPORT = {
        ReportType.UNSOLICITED: "Unwanted messages you do not wish to receive.",
        ReportType.SPAM: "Unsolicited advertisement.",
        ReportType.SUSPICIOUS: "Professional messages that seem to be deceptive or fraudulent.",
        ReportType.HARMFUL: "Promotion of behaviors or actions which harmful if carried out.",
        ReportType.DEFAMATION: "A message which content is defaming or slanderous towards someone.",
        ReportType.OFFENSIVE: "A message which content is detestable or repulsive.",
        ReportType.HATEFUL: "A message that is malicious or insulting and spreads hate.",
        ReportType.SEDITION: "Sedition to mischief and spread hate or commit crimes.",
        ReportType.HARASSMENT: "A message is considered to be harassment or stalking.",
        ReportType.MENACE: "A message is intimidating and menacing or contains direct threats.",
        ReportType.BLACKMAIL: "A message that intimidates you to conform to demands.",
        ReportType.SOLICITATION: "Solicitation for criminal purposes.",
        ReportType.CONSPIRACY: "Conspiracy to commit a crime.",
        ReportType.GRAPHIC: "Undesirable graphic content.",
        ReportType.ADULT: "Mature content of sexual nature.",
    }


class Helper:
    """Portfolio helper utility."""

    PATH = PurePosixPath("/portfolios/")

    @classmethod
    def group_suffix(cls, group: Tuple[str]) -> Tuple[str]:
        """Suffixes of fields from a group."""
        return {Definitions.SUFFIXES[field] for field in group}
