# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
""""Docstring"""
from .entities import Person, Ministry, Church, PrivateKeys, Keys
from .profiles import PersonProfile, MinistryProfile, ChurchProfile
from .domain import Domain, Node, Network
from .statements import Verified, Trusted, Revoked
from .messages import Note, Instant, Mail, Share, Report
from .envelope import Envelope

from typing import Union


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
