# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
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
    """Short summary."""
    node = UuidField()
    ip = IPField(required=False, multiple=True)
    hostname = StringField(required=False, multiple=True)


class Location(BaseDocument):
    """Short summary."""
    ip = IPField(required=False, multiple=True)
    hostname = StringField(required=False, multiple=True)


class Domain(Document, UpdatedMixin):
    """Short summary."""
    type = TypeField(value=DocType.NET_DOMAIN)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.NET_DOMAIN)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        validate = [BaseDocument, Document, IssueMixin, Domain, UpdatedMixin]
        self._check_validate(validate)
        return True


class Node(Document, UpdatedMixin):
    """Short summary."""
    type = TypeField(value=DocType.NET_NODE)
    domain = UuidField()
    role = ChoiceField(choices=["client", "server", "backup"])
    device = StringField()
    serial = StringField()
    location = DocumentField(required=False, t=Location)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.NET_NODE)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        validate = [BaseDocument, Document, IssueMixin, Node, UpdatedMixin]
        self._check_validate(validate)
        return True


class Network(Document, UpdatedMixin):
    """Short summary."""
    type = TypeField(value=DocType.NET_NETWORK)
    domain = UuidField()
    hosts = DocumentField(t=Host, multiple=True)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.NET_NETWORK)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        validate = [BaseDocument, Document, IssueMixin, Network, UpdatedMixin]
        self._check_validate(validate)
        return True
