# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
from ..utils import Util
from ..error import Error
from .model import (
    BaseDocument,
    StringField,
    IPField,
    UuidField,
    DocumentField,
    TypeField,
    ChoiceField,
)
from .document import DocType, Document, UpdatedMixin, IssueMixin


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
    type = TypeField(value=DocType.NET_DOMAIN)

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.NET_DOMAIN)
        return True


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
    type = TypeField(value=DocType.NET_NODE)
    domain = UuidField()
    role = ChoiceField(choices=["client", "server", "backup"])
    device = StringField()
    serial = StringField()
    location = DocumentField(required=False, doc_class=Location)

    def _check_location(self):
        if self.location and self.role == "server":
            if not (self.location.hostname or self.location.ip):
                raise Util.exception(Error.DOCUMENT_NO_LOCATION)

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.NET_NODE)
        self._check_location()
        return True


class Network(Document, UpdatedMixin):
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
    type = TypeField(value=DocType.NET_NETWORK)
    domain = UuidField()
    hosts = DocumentField(doc_class=Host, multiple=True)

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.NET_NETWORK)
        info = False
        for host in self.hosts if self.hosts else []:
            if host.hostname or host.ip:
                info = True
        if not info:
            raise Util.exception(Error.DOCUMENT_NO_HOST)
        return True
