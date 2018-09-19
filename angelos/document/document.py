import datetime
import uuid
from .model import BaseDocument, UuidField, DateField, StringField
from .issuance import IssueMixin


class Document(IssueMixin, BaseDocument):
    id = UuidField(init=uuid.uuid4)
    created = DateField(init=datetime.date.today)
    expires = DateField(init=lambda: (
        datetime.date.today() + datetime.timedelta(13*365/12)))
    type = StringField()
