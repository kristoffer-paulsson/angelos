# cython: language_level=3
"""
Document model.

The document model defines the documents and its fields and fieldtypes avaiable
within the angelos project. Each document has a special meaning and represents
something.
"""
from .document import DocType
from .entities import Person, Ministry, Church, PrivateKeys, Keys
from .profiles import (
    PersonProfile, MinistryProfile, ChurchProfile, Address, Social)
from .domain import Domain, Node, Network, Host, Location
from .statements import Verified, Trusted, Revoked
from .messages import Note, Instant, Mail, Share, Report, Attachment
from .envelope import Envelope, Header

from typing import Union


Document = Union[
    Person, Ministry, Church, PrivateKeys, Keys, PersonProfile,
    MinistryProfile, ChurchProfile, Domain, Node, Network, Verified, Trusted,
    Revoked, Note, Instant, Mail, Share, Report, Envelope]
Entity = Union[Person, Ministry, Church]
Profile = Union[PersonProfile, MinistryProfile, ChurchProfile]
Statement = Union[Verified, Trusted, Revoked]
Message = Union[Note, Instant, Mail, Share, Report]


__all__ = [
    'Document',
    'Entity',
    'Profile',
    'DocType',
    'Person',
    'Ministry',
    'Church',
    'PrivateKeys',
    'Keys',
    'PersonProfile',
    'MinistryProfile',
    'ChurchProfile',
    'Address',
    'Social',
    'Domain',
    'Node',
    'Network',
    'Host',
    'Location',
    'Verified',
    'Trusted',
    'Revoked',
    'Note',
    'Instant',
    'Mail',
    'Share',
    'Report',
    'Envelope',
    'Header',
    'Message',
    'Attachment'
]
