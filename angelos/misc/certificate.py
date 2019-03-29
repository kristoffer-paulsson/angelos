from .document import Document
from .model import StringField, UuidField


class Affidavit(Document):
    pass


class Verified(Affidavit):
    type = StringField(value='aff.verified')
    owner = UuidField(required=True)


class Trusted(Affidavit):
    type = StringField(value='aff.trusted')
    owner = UuidField(required=True)


class Revoked(Affidavit):
    type = StringField(value='aff.revoked')
    issuance = UuidField(required=True)
