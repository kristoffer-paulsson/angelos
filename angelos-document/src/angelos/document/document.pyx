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
import uuid

import msgpack
from angelos.common.policy import policy, PolicyException
from angelos.document.model import DocumentMeta, BaseDocument, UuidField, DateField, TypeField, SignatureField


class DocumentError(PolicyException):
    DOCUMENT_SHORT_EXPIRY = ("Expiry date to short", 604)
    DOCUMENT_INVALID_TYPE = ("Invalid type set", 605)
    DOCUMENT_PERSON_NAMES = ("Given name not in names", 606)
    DOCUMENT_NO_LOCATION = ("Node document has no valid location set", 610)
    DOCUMENT_NO_HOST = ("Network document has no valid hosts", 611)
    DOCUMENT_UPDATED_NOT_LATEST = ("Document updated earlier than created", 612)
    DOCUMENT_WRONG_ID = ("Document ID is not the same as Containing document.", 613)
    DOCUMENT_OWNER_IS_ISSUER = ("Document owner can not be the same as issuer.", 614)


DOCUMENT_EXPIRY_PERIOD = 13 * 365 / 12


class IssueMixin(metaclass=DocumentMeta):
    """Short summary.

    Attributes
    ----------
    signature : SignatureField
        Description of attribute `signature`.
    issuer : UuidField
        Description of attribute `issuer`.
    """
    signature = SignatureField()
    issuer = UuidField()

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return True


class OwnerMixin(metaclass=DocumentMeta):
    """Short summary.

    Attributes
    ----------
    owner : UuidField
        Description of attribute `owner`.
    """
    owner = UuidField()

    @policy(b"C", 22)
    def _check_issuer(self) -> bool:
        """Checks that the issuer is not the owner.

        Documents having an "owner" field should not be self issued.
        """
        if hasattr(self, "issuer"):  # TODO: Check if attribute check for "issue" can be implemented differently.
            if self.issuer == self.owner:
                raise DocumentError(*DocumentError.DOCUMENT_OWNER_IS_ISSUER, {"owner": self.owner})
        return True

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_issuer()
        ])


class UpdatedMixin(metaclass=DocumentMeta):
    """Short summary.

    Attributes
    ----------
    updated : DateField
        Description of attribute `updated`.
    """
    updated = DateField(required=False)

    @policy(b"C", 23)
    def _check_updated_latest(self) -> bool:
        """Checks that updated is newer than created."""
        if bool(self.updated) and hasattr(self, "created"):
            if self.created > self.updated:
                raise DocumentError(
                    *DocumentError.DOCUMENT_UPDATED_NOT_LATEST,
                    {"id": getattr(self, "id", None)})
        return True

    def apply_rules(self) -> bool:
        """Applies all class related rules to document.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_updated_latest()
        ])

    def renew(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        today = datetime.date.today()
        self.updated = today
        if hasattr(self, "expires"):
            setattr(self, "expires", today + datetime.timedelta(self.period()))
        if hasattr(self, "signature"):
            self._fields["signature"].redo = True
            setattr(self, "signature", None)


class ChangeableMixin(UpdatedMixin):
    """Changeable is an updatable mixin that gives provision to change the value of some fields."""

    def changeables(self) -> tuple:
        """Fields that are allowed to change when updated."""
        return tuple()


class Document(IssueMixin, BaseDocument):
    """Short summary.

    Attributes
    ----------
    id : UuidField
        Description of attribute `id`.
    created : DateField
        Description of attribute `created`.
    expires : DateField
        Description of attribute `expires`.
    """
    id = UuidField(init=uuid.uuid4)
    created = DateField(init=datetime.date.today)
    expires = DateField(
        init=lambda: (
            datetime.date.today() + datetime.timedelta(DOCUMENT_EXPIRY_PERIOD)
        )
    )
    type = TypeField(value=0)

    @policy(b"C", 24)
    def _check_expiry_period(self) -> bool:
        """Checks the expiry time period.

        The time period between update date and
        expiry date should not be less than 13 months.
        """
        if self.expires:
            touched = self.get_touched()
            if (self.expires - touched) < datetime.timedelta(self.period() - 1):
                raise DocumentError(
                    *DocumentError.DOCUMENT_SHORT_EXPIRY,
                    {"expected": datetime.timedelta(self.period()), "current": self.expires - touched})
        return True

    @policy(b"C", 25)
    def _check_doc_type(self, _type) -> bool:
        """Checks that document type is set.

        This check is called from each finalized document!

        Parameters
        ----------
        _type : type
            Description of parameter `_type`.

        Returns
        -------
        type
            Description of returned object.

        """
        if not self.type == _type:
            raise DocumentError(
                *DocumentError.DOCUMENT_INVALID_TYPE,
                {"expected": _type, "current": self.type})
        return True

    def period(self) -> float:
        """The Delta period to expiry date.

        Returns (datetime.timedelta):
            The Delta period.

        """
        return DOCUMENT_EXPIRY_PERIOD

    def get_touched(self) -> datetime.date:
        """Latest touch, created or updated date."""
        return getattr(self, "updated", None) or self.created

    def __lt__(self, other):
        return self.get_touched() < other.get_touched()

    def __le__(self, other):
        return self.get_touched() <= other.get_touched()

    def __gt__(self, other):
        return self.get_touched() > other.get_touched()

    def __ge__(self, other):
        return self.get_touched() >= other.get_touched()

    def get_owner(self) -> uuid.UUID:
        """Correct owner of document."""
        return getattr(self, "owner", None) or self.issuer

    @policy(b"D", 26, "Document")
    def validate(self) -> bool:
        """Validate document according to the rules.

        Returns (bool):
            True if everything validates.

        """
        # valid = list()
        # classes = set(self.__class__.mro())

        # for cls in classes:
        #    if hasattr(cls, "apply_rules"):
        #        valid.append(cls.apply_rules(self))

        if not all([
            func(self) for func in {
                cls.apply_rules for cls in self.__class__.mro() if hasattr(cls, "apply_rules")}]):
            raise PolicyException()
        return True

    def is_way_old(self) -> bool:  # FIXME: Write a unittest.
        """Is the document older than three years?"""
        return datetime.date.today() - self.get_touched() > datetime.timedelta(365*3+1)

    def is_expired(self) -> bool:
        """Is the document expired?"""
        return self.expires < datetime.date.today()

    def expires_soon(self) -> bool:
        """Within a month of expiry.

        Returns
        -------
        type
            Description of returned object.

        """
        month = self.expires - datetime.timedelta(days=self.period())
        today = datetime.date.today()
        return month <= today <= self.expires

    def compare(self, document: "Document") -> bool:  # FIXME: Write a unittest
        """Compare two documents to see if they are the same even if other fields mismatch."""
        return (self.id.bytes == document.id.bytes) and (self.issuer.bytes == document.issuer.bytes)

    # TODO: Deprecated, remove when nothing depends.
    def save(self) -> bytes:
        """Serialize document.

        Returns
        -------
        bytes
            Stream of bytes representing the document.

        """
        return msgpack.packb(
            self.export_bytes(),
            use_bin_type=True,
            strict_types=True
        )


# TODO: Deprecated, remove when nothing depends.
class DocType:
    """Short summary."""
    NONE = 0

    KEYS_PRIVATE = 1

    KEYS = 10

    ENTITY_PERSON = 20
    ENTITY_MINISTRY = 21
    ENTITY_CHURCH = 22
    PROF_PERSON = 30
    PROF_MINISTRY = 31
    PROF_CHURCH = 32

    NET_DOMAIN = 40
    NET_NODE = 41
    NET_NETWORK = 42

    STAT_VERIFIED = 50
    STAT_TRUSTED = 51
    STAT_REVOKED = 52

    COM_ENVELOPE = 60

    COM_NOTE = 70
    COM_INSTANT = 71
    COM_MAIL = 72
    COM_SHARE = 73
    COM_REPORT = 74

    CACHED_MSG = 700
