from .document import Document
from .model import BaseDocument, StringField, UuidField, ChoiceField, DateField

from ..utils import Util
from ..error import Error


class Network(Document):
    type = StringField(value='net.network')
    owner = UuidField()
    updated = DateField(required=False)

    def _validate(self):
        # Validate that "type" is of correct type
        if not self.type == 'net.network':
            raise Util.exception(
                Error.DOCUMENT_INVALID_TYPE,
                {'expected': 'net.network',
                 'current': self.type})
        return True

    def validate(self):
        validate = True
        validate = validate if BaseDocument._validate(self) else False
        validate = validate if Document._validate(self) else False
        validate = validate if Network._validate(self) else False
        return validate


class Node(Document):
    type = StringField(value='net.node')
    network = UuidField()
    owner = UuidField()
    updated = DateField(required=False)
    role = ChoiceField(choices=['server', 'client', 'backup'])
    device = StringField()
    serial = StringField()

    def _validate(self):
        # Validate that "type" is of correct type
        if not self.type == 'net.node':
            raise Util.exception(
                Error.DOCUMENT_INVALID_TYPE,
                {'expected': 'net.node',
                 'current': self.type})
        return True

    def validate(self):
        validate = True
        validate = validate if BaseDocument._validate(self) else False
        validate = validate if Document._validate(self) else False
        validate = validate if Node._validate(self) else False
        return validate
