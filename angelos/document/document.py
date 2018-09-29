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

    def _validate(self):
        validate = True

        # Validate that "expires" is at least 13 months in the future compared
        # to "created" if "updated" is null
        if not bool(self.updated):
            if not (self.expires - self.created >=
                    datetime.timedelta(13*365/12)):
                validate = False

        return validate
