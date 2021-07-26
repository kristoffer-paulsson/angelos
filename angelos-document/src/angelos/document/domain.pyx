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
"""Module docstring."""
import ipaddress
from typing import Union

from angelos.common.policy import policy
from angelos.document.document import DocType, Document, UpdatedMixin, ChangeableMixin, DocumentError
from angelos.document.model import BaseDocument, StringField, IPField, UuidField, DocumentField, TypeField, ChoiceField


class Host(BaseDocument):
    """Short summary.

    Attributes
    ----------
    node : UuidField
        Description of attribute `node`.
    ip : IPField
        Description of attribute `ip`.
    hostname : StringField
        Description of attribute `hostname`.
    """
    node = UuidField()
    ip = IPField(required=False, multiple=True)
    hostname = StringField(required=False, multiple=True)


class Location(BaseDocument):
    """Short summary.

    Attributes
    ----------
    ip : IpField
        Description of attribute `ip`.
    hostname : StringField
        Description of attribute `hostname`.
    """
    ip = IPField(required=False, multiple=True)
    hostname = StringField(required=False, multiple=True)


class Domain(Document, UpdatedMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.NET_DOMAIN))

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.NET_DOMAIN)
        ])


class Node(Document, UpdatedMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    domain : UuidField
        Description of attribute `domain`.
    role : ChoiceField
        Description of attribute `role`.
    device : StringField
        Description of attribute `device`.
    serial : StringField
        Description of attribute `serial`.
    location : DocumentField
        Description of attribute `location`.
    """
    type = TypeField(value=int(DocType.NET_NODE))
    domain = UuidField()
    role = ChoiceField(choices=["client", "server", "backup"])
    device = StringField()
    serial = StringField()
    location = DocumentField(required=False, doc_class=Location)

    @policy(b"C", 27)
    def _check_location(self):
        if self.location and self.role == "server":
            if not (self.location.hostname or self.location.ip):
                raise DocumentError(*DocumentError.DOCUMENT_NO_LOCATION)
        return True

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.NET_NODE),
            self._check_location()
        ])

    def iploc(self) -> Union[ipaddress.IPv4Address, ipaddress.IPv6Address]:
        """IP address for a location."""
        return [ip for ip in (self.location.ip if self.location else []) if ip]


class Network(Document, ChangeableMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    domain : UuidField
        Description of attribute `domain`.
    hosts : DocumentField
        Description of attribute `hosts`.
    """
    type = TypeField(value=int(DocType.NET_NETWORK))
    domain = UuidField()
    hosts = DocumentField(doc_class=Host, multiple=True)

    @policy(b"C", 28)
    def _check_host(self) -> bool:
        for host in self.hosts if self.hosts else []:
            if not (host.hostname or host.ip):
                raise DocumentError(*DocumentError.DOCUMENT_NO_HOST)
        return True

    def changeables(self) -> tuple:
        """Fields that are changeable when updating."""
        return "hosts",

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.NET_NETWORK),
            self._check_host()
        ])

    def iploc(self) -> Union[ipaddress.IPv4Address, ipaddress.IPv6Address]:
        """IP address for a location from document."""
        return [ip for host in self.hosts for ip in host if ip]
