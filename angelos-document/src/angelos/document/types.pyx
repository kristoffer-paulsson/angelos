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
"""Types supporting python 3 typing.

Don't use these types with isinstance(), only in the method declaration.
However these types can be used with Utils.is_typing() that wraps isinstance()."""
from typing import Union

from angelos.document.domain import Domain, Node, Network
from angelos.document.entities import Person, Ministry, Church, PrivateKeys, Keys
from angelos.document.envelope import Envelope
from angelos.document.messages import Note, Instant, Mail, Share, Report
from angelos.document.profiles import PersonProfile, MinistryProfile, ChurchProfile
from angelos.document.statements import Verified, Trusted, Revoked

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
