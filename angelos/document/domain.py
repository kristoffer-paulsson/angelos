"""Module docstring."""
from .model import (
    BaseDocument, StringField, IPField, UuidField, DocumentField, TypeField)
from .document import Document, UpdatedMixin, IssueMixin


class Host(BaseDocument):
    node = UuidField()
    ip = IPField(required=False, multiple=True)
    hostname = StringField(required=False, multiple=True)


class Location(BaseDocument):
    ip = IPField(required=False, multiple=True)
    hostname = StringField(required=False, multiple=True)


class Domain(Document, UpdatedMixin):
    type = TypeField(value=Document.Type.NET_DOMAIN)

    def _validate(self):
        self._check_type(Document.Type.NET_DOMAIN)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Domain, UpdatedMixin]
        self._check_validate(validate)
        return True


class Network(Document, UpdatedMixin):
    type = TypeField(value=Document.Type.NET_NETWORK)
    domain = UuidField()
    hosts = DocumentField(t=Host, multiple=True)

    def _validate(self):
        self._check_type(Document.Type.NET_NETWORK)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Network, UpdatedMixin]
        self._check_validate(validate)
        return True


class Node(Document, UpdatedMixin):
    type = TypeField(value=Document.Type.NET_NODE)
    domain = UuidField()
    role = StringField()
    device = StringField()
    serial = StringField()
    location = DocumentField(required=False, t=Location)

    def _validate(self):
        self._check_type(Document.Type.NET_NODE)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Node, UpdatedMixin]
        self._check_validate(validate)
        return True
