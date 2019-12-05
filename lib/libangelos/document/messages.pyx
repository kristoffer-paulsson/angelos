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
    DateField,
    BinaryField,
    DocumentField,
    UuidField,
    TypeField,
    DateTimeField,
)
from .document import DocType, Document, OwnerMixin, IssueMixin


class Attachment(BaseDocument):
    """Short summary.

    Attributes
    ----------
    name : StringField
        Description of attribute `name`.
    mime : StringField
        Description of attribute `mime`.
    data : BinaryField
        Description of attribute `data`.
    """
    name = StringField()
    mime = StringField()
    data = BinaryField()


class Message(Document, OwnerMixin):
    """Short summary.

    Attributes
    ----------
    expires : DateField
        Description of attribute `expires`.
    reply : UuidField
        Description of attribute `reply`.
    body : StringField
        Description of attribute `body`.
    posted : DateTimeField
        Description of attribute `posted`.
    """
    expires = DateField(required=False)
    reply = UuidField(required=False)
    body = StringField(required=False)
    posted = DateTimeField()


class Note(Message):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.COM_NOTE))

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_doc_type(DocType.COM_NOTE)
        return True


class Instant(Message):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    body : BinaryField
        Description of attribute `body`.
    mime : StringField
        Description of attribute `mime`.
    """
    type = TypeField(value=int(DocType.COM_INSTANT))
    body = BinaryField()
    mime = StringField()

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_doc_type(DocType.COM_INSTANT)
        return True


class Mail(Message):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    subject : StringField
        Description of attribute `subject`.
    attachments : DocumentField
        Description of attribute `attachments`.
    """
    type = TypeField(value=int(DocType.COM_MAIL))
    subject = StringField(required=False)
    attachments = DocumentField(required=False, doc_class=Attachment, multiple=True)

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_doc_type(DocType.COM_MAIL)
        return True


class Share(Mail):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.COM_SHARE))

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_doc_type(DocType.COM_SHARE)
        return True


class Report(Mail):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.COM_REPORT))

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_doc_type(DocType.COM_REPORT)
        return True
