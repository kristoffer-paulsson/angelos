import datetime
import uuid

from ..utils import Util
from ..error import Error
from .model import BaseDocument, UuidField, DateField, StringField
from .issuance import IssueMixin


class Document(IssueMixin, BaseDocument):
    id = UuidField(required=True, init=uuid.uuid4)
    created = DateField(required=True, init=datetime.date.today)
    expires = DateField(required=True, init=lambda: (
        datetime.date.today() + datetime.timedelta(13*365/12)))
    type = StringField()

    def _validate(self):
        # Validate that "expires" is at least 13 months in the future compared
        # to "created" if "updated" is null
        try:
            if not bool(self.updated):
                if self.expires - self.created > datetime.timedelta(13*365/12):
                    raise Util.exception(
                        Error.DOCUMENT_SHORT_EXPIREY,
                        {'expected': datetime.timedelta(13*365/12),
                         'current': self.expires - self.created})
        except AttributeError:
            pass
        return True


class File(BaseDocument):
    id = UuidField(init=uuid.uuid4)
    created = DateField(init=datetime.date.today)
    mime = StringField()
    data = StringField()
    issuer = UuidField()
