# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import datetime

from ..utils import Util
from ..error import Error

from .model import (
    BaseDocument,
    DateField,
    StringField,
    UuidField,
    DocumentField,
    BinaryField,
    TypeField,
    SignatureField,
    DateTimeField,
)
from .document import DocType, Document, OwnerMixin, IssueMixin


class Header(BaseDocument):
    """Short summary.

    Attributes
    ----------
    op : StringField
        Description of attribute `op`.
    issuer : UuidField
        Description of attribute `issuer`.
    timestamp : DateTimeField
        Description of attribute `timestamp`.
    signature : SignatureField
        Description of attribute `signature`.
    """
    op = StringField()
    issuer = UuidField()
    timestamp = DateTimeField()
    signature = SignatureField()

    class Op:
        """Short summary."""
        SEND = "SEND"
        ROUTE = "RTE"
        RECEIVE = "RECV"


class Envelope(Document, OwnerMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    expires : DateField
        Description of attribute `expires`.
    message : BinaryField
        Description of attribute `message`.
    header : DocumentField
        Description of attribute `header`.
    posted : DateTimeField
        Description of attribute `posted`.
    """
    type = TypeField(value=DocType.COM_ENVELOPE)
    expires = DateField(
        init=lambda: (datetime.date.today() + datetime.timedelta(31))
    )
    message = BinaryField(limit=131072)
    header = DocumentField(required=False, doc_class=Header, multiple=True)
    posted = DateTimeField()

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.COM_ENVELOPE)

        if self.expires - self.created > datetime.timedelta(31):
            raise Util.exception(
                Error.DOCUMENT_SHORT_EXPIREY,
                {
                    "expected": datetime.timedelta(31),
                    "current": self.expires - self.created,
                },
            )

        return True