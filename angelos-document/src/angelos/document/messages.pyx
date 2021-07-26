#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""Module docstring."""
import datetime

from angelos.common.policy import policy
from angelos.document.document import DocType, Document, OwnerMixin, DocumentError
from angelos.document.model import BaseDocument, StringField, DateField, BinaryField, DocumentField, UuidField, \
    TypeField, DateTimeField


MESSAGE_EXPIRY_PERIOD = 31


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

    def period(self) -> float:
        """The Delta period to expiry date.

        Returns (datetime.timedelta):
            The Delta period.

        """
        return MESSAGE_EXPIRY_PERIOD


class Note(Message):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.COM_NOTE))

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.COM_NOTE)
        ])


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

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.COM_INSTANT)
        ])


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

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.COM_MAIL)
        ])


class Share(Mail):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.COM_SHARE))

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.COM_SHARE)
        ])


class Report(Mail):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.COM_REPORT))

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.COM_REPORT)
        ])
