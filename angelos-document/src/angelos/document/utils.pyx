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
"""Helper utilities for documents."""
import datetime
import uuid
from typing import Tuple

import msgpack
from angelos.common.utils import Util


class Definitions:
    """Definitions of document types."""
    NONE = 0

    KEYS_PRIVATE = 1

    KEYS = 10

    ENTITY_PERSON = 20
    ENTITY_MINISTRY = 21
    ENTITY_CHURCH = 22
    PROF_PERSON = 30
    PROF_MINISTRY = 31
    PROF_CHURCH = 32

    NET_DOMAIN = 40
    NET_NODE = 41
    NET_NETWORK = 42

    STAT_VERIFIED = 50
    STAT_TRUSTED = 51
    STAT_REVOKED = 52

    COM_ENVELOPE = 60

    COM_NOTE = 70
    COM_INSTANT = 71
    COM_MAIL = 72
    COM_SHARE = 73
    COM_REPORT = 74

    CACHED_MSG = 700

    EXTENSION = {
        0: None,  # NONE

        1: ".pky",  # KEYS_PRIVATE

        10: ".key",  # KEYS

        20: ".ent",  # ENTITY_PERSON
        21: ".ent",  # ENTITY_MINISTRY
        22: ".ent",  # ENTITY_CHURCH
        30: ".pfl",  # PROF_PERSON
        31: ".pfl",  # PROF_MINISTRY
        32: ".pfl",  # PROF_CHURCH

        40: ".dmn",  # NET_DOMAIN
        41: ".nod",  # NET_NODE
        42: ".net",  # NET_NETWORK

        50: ".ver",  # STAT_VERIFIED
        51: ".rst",  # STAT_TRUSTED
        52: ".rev",  # STAT_REVOKED

        60: ".env",  # COM_ENVELOPE

        70: ".msg",  # COM_NOTE
        71: ".msg",  # COM_INSTANT
        72: ".msg",  # COM_MAIL
        73: ".msg",  # COM_SHARE
        74: ".msg",  # COM_REPORT

        700: ".cmsg"  # CACHED_MSG
    }

    CLASS = {
        0: type(None),  # NONE

        1: ("angelos.document.entities", "PrivateKeys"),  # KEYS_PRIVATE

        10: ("angelos.document.entities", "Keys"),  # KEYS

        20: ("angelos.document.entities", "Person"),  # ENTITY_PERSON
        21: ("angelos.document.entities", "Ministry"),  # ENTITY_MINISTRY
        22: ("angelos.document.entities", "Church"),  # ENTITY_CHURCH
        30: ("angelos.document.profile", "PersonProfile"),  # PROF_PERSON
        31: ("angelos.document.profile", "MinistryProfile"),  # PROF_MINISTRY
        32: ("angelos.document.profile", "ChurchProfile"),  # PROF_CHURCH

        40: ("angelos.document.domain", "Domain"),  # NET_DOMAIN
        41: ("angelos.document.domain", "Node"),  # NET_NODE
        42: ("angelos.document.domain", "Network"),  # NET_NETWORK

        50: ("angelos.document.statements", "Verified"),  # STAT_VERIFIED
        51: ("angelos.document.statements", "Trusted"),  # STAT_TRUSTED
        52: ("angelos.document.statements", "Revoked"),  # STAT_REVOKED

        60: ("angelos.document.envelope", "Envelope"),  # COM_ENVELOPE

        70: ("angelos.document.messages", "Note"),  # COM_NOTE
        71: ("angelos.document.messages", "Instant"),  # COM_INSTANT
        72: ("angelos.document.messages", "Mail"),  # COM_MAIL
        73: ("angelos.document.messages", "Share"),  # COM_SHARE
        74: ("angelos.document.messages", "Report"),  # COM_REPORT

        700: ("angelos.document.misc", "StoredLetter")  # CACHED_MSG
    }

    # FIXME: Write unittests.
    @classmethod
    def klass(cls, doc_type: int) -> "DocumentMeta":
        """Get class for document type."""
        return Util.klass(*cls.CLASS[doc_type])


class Helper:
    """Document helper utility."""

    EXCLUDE = ("signature",)
    EXCLUDE_UPDATE = ("updated", "expires")

    # FIXME: Write unittests
    @classmethod
    def excludes(cls, document: "Document") -> Tuple[str]:
        """Fields that can be excluded from flattening."""
        if hasattr(document, "changeables"):
            return cls.EXCLUDE + cls.EXCLUDE_UPDATE + document.changeables()
        elif hasattr(document, "updated"):
            return cls.EXCLUDE + cls.EXCLUDE_UPDATE
        else:
            return cls.EXCLUDE

    # FIXME: Write unittests.
    @classmethod
    def flatten_document(cls, document: "Document", exclude: tuple = tuple()) -> bytes:
        """Flatten the data of a Document in a standardized way to a byte string.

        Args:
            document (Document):
                The document to be flattened.
            exclude (tuple):
                List of fieldnames to exclude from flattening.

        Returns (bytes):
            The flattened document as bytes.

        """
        dictionary = dict()
        for field, data in sorted(document.export_bytes().items()):
            if field not in exclude:
                dictionary[field] = data

        return cls.flatten_dictionary(dictionary)

    @classmethod
    def flatten_list(cls, data_list: list) -> bytes:
        """Flatten list of items that may be dictionaries, bytes and None."""
        stream = bytes()
        for item in data_list:
            if isinstance(item, dict):
                stream += cls.flatten_dictionary(item)
            elif isinstance(item, (bytes, bytearray)):
                stream += item
            elif isinstance(item, type(None)):
                pass
            else:
                raise TypeError()

        return stream

    @classmethod
    def flatten_dictionary(cls, data_dict: dict) -> bytes:
        """Flatten dictionaries that may have dictionaries, lists, bytes and None."""
        stream = bytes()
        for field, data in sorted(data_dict.items()):
            stream += field.encode()
            if isinstance(data, list):
                stream += cls.flatten_list(data)
            elif isinstance(data, dict):
                stream += cls.flatten_dictionary(data)
            elif isinstance(data, (bytes, bytearray)):
                stream += data
            elif isinstance(data, type(None)):
                pass
            else:
                raise TypeError()

        return stream

    # FIXME: Write unittests.
    @classmethod
    def serialize(cls, document: "Document") -> bytes:
        """"Serialize document into streams of bytes."""
        return msgpack.packb(document.export_bytes(), use_bin_type=True, strict_types=True)

    # FIXME: Write unittests.
    @classmethod
    def deserialize(cls, data: bytes) -> "Document":
        """Build document from stream of bytes."""
        doc_obj = msgpack.unpackb(data, raw=False)
        return Definitions.klass(int.from_bytes(doc_obj["type"], byteorder="big")).build(doc_obj)

    # FIXME: Write unittests.
    @classmethod
    def extension(cls, doc_type: int) -> str:
        """Get file extension for document type."""
        return Definitions.EXTENSION[doc_type]

    @classmethod
    def meta(cls, document: "Document") -> Tuple[datetime.datetime, datetime.datetime, uuid.UUID]:
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