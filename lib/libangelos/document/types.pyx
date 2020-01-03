# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Types supporting python 3 typing.

Don't use these types with isinstance(), only in the method declaration.
However these types can be used with Utils.is_typing() that wraps isinstance()."""
from typing import Union

from libangelos.document.domain import Domain, Node, Network
from libangelos.document.entities import Person, Ministry, Church, PrivateKeys, Keys
from libangelos.document.envelope import Envelope
from libangelos.document.messages import Note, Instant, Mail, Share, Report
from libangelos.document.profiles import PersonProfile, MinistryProfile, ChurchProfile
from libangelos.document.statements import Verified, Trusted, Revoked

DocumentT = Union[
    Person,
    Ministry,
    Church,
    PrivateKeys,
    Keys,
    PersonProfile,
    MinistryProfile,
    ChurchProfile,
    Domain,
    Node,
    Network,
    Verified,
    Trusted,
    Revoked,
    Note,
    Instant,
    Mail,
    Share,
    Report,
    Envelope,
]
EntityT = Union[Person, Ministry, Church]
ProfileT = Union[PersonProfile, MinistryProfile, ChurchProfile]
StatementT = Union[Verified, Trusted, Revoked]
MessageT = Union[Note, Instant, Mail, Share, Report]
