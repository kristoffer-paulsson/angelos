# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import datetime
import uuid
import enum

from ..utils import Util
from ..error import Error
from .model import (
    DocumentMeta,
    BaseDocument,
    UuidField,
    DateField,
    TypeField,
    SignatureField,
)


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

    def apply_rules(self):
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

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return True


class UpdatedMixin(metaclass=DocumentMeta):
    """Short summary.

    Attributes
    ----------
    updated : DateField
        Description of attribute `updated`.
    """
    updated = DateField(required=False)

    def _check_expiry_period(self):
        """Checks that the expiry time period.

        The time period between update date and
        expiry date should not be less than 13 months.
        """
        if bool(self.updated) and hasattr(self, "expires"):
            if (self.expires - self.updated) < datetime.timedelta(
                13 * 365 / 12 - 1
            ):
                raise Util.exception(
                    Error.DOCUMENT_SHORT_EXPIREY,
                    {
                        "expected": datetime.timedelta(13 * 365 / 12),
                        "current": self.expires - self.updated,
                    },
                )

    def apply_rules(self):
        """Applies all class related rules to document.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_expiry_period()
        return True

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
            setattr(self, "expires", today + datetime.timedelta(13 * 365 / 12))
        if hasattr(self, "signature"):
            self._fields["signature"].redo = True
            setattr(self, "signature", None)


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
            datetime.date.today() + datetime.timedelta(13 * 365 / 12)
        )
    )
    type = TypeField(value=0)

    def _check_expiry_period(self):
        """Checks that the expiry time period.

        The time period between update date and
        expiry date should not be less than 13 months.
        """
        sdate = (
            self.updated if getattr(self, "updated", None) else self.created
        )
        if (self.expires - sdate) < datetime.timedelta(13 * 365 / 12 - 1):
            raise Util.exception(
                Error.DOCUMENT_SHORT_EXPIREY,
                {
                    "expected": datetime.timedelta(13 * 365 / 12),
                    "current": self.expires - sdate,
                },
            )

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return True

    def _check_type(self, _type):
        """Short summary.

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
            raise Util.exception(
                Error.DOCUMENT_INVALID_TYPE,
                {"expected": _type, "current": self.type},
            )

    def validate(self):
        """Short summary.

        Parameters
        ----------
        instance_list : type
            Description of parameter `_list`.

        Returns
        -------
        type
            Description of returned object.

        """
        for cls in self.__class__.mro()[:-1]:
            cls.apply_rules(self)
        return True

    def expires_soon(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        month = self.expires - datetime.timedelta(days=365 / 12)
        today = datetime.date.today()
        if today >= month and today <= self.expires:
            return True
        else:
            return False


class DocType(enum.IntEnum):
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
