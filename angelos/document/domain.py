from .model import (
    BaseDocument, StringField, IPField, UuidField, DocumentField)
from .document import Document, UpdatedMixin, IssueMixin


class Host(BaseDocument):
    node = UuidField()
    ip = IPField(required=False, multiple=True)
    hostname = StringField(required=False, multiple=True)


class Location(BaseDocument):
    ip = IPField(required=False, multiple=True)
    hostname = StringField(required=False, multiple=True)


class Domain(Document, UpdatedMixin):
    type = StringField(value='net.domain')

    def _validate(self):
        self._check_type('net.domain')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Domain, UpdatedMixin]
        self._check_validate(self, validate)
        return True


class Network(Document, UpdatedMixin):
    type = StringField(value='net.network')
    domain = UuidField()
    hosts = DocumentField(t=Host, multiple=True)

    def _validate(self):
        self._check_type('net.network')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Network, UpdatedMixin]
        self._check_validate(self, validate)
        return True


class Node(Document, UpdatedMixin):
    type = StringField(value='net.node')
    domain = UuidField()
    role = StringField()
    device = StringField()
    serial = StringField()
    location = DocumentField(required=False, t=Location)

    def _validate(self):
        self._check_type('net.node')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Node, UpdatedMixin]
        self._check_validate(self, validate)
        return True
