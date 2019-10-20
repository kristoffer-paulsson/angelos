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
    ChoiceField,
    EmailField,
    BinaryField,
    DocumentField,
    TypeField,
)
from .document import DocType, Document, UpdatedMixin, IssueMixin
from .entity_mixin import PersonMixin, MinistryMixin, ChurchMixin


class Address(BaseDocument):
    """Short summary."""
    co = StringField(required=False)
    organisation = StringField(required=False)
    department = StringField(required=False)
    apartment = StringField(required=False)
    floor = StringField(required=False)
    building = StringField(required=False)
    street = StringField(required=False)
    number = StringField(required=False)
    area = StringField(required=False)
    city = StringField(required=False)
    pobox = StringField(required=False)
    zip = StringField(required=False)
    subregion = StringField(required=False)
    region = StringField(required=False)
    country = StringField(required=False)


class Social(BaseDocument):
    """Short summary."""
    token = StringField()
    service = StringField()


class Profile(Document, UpdatedMixin):
    """Short summary."""
    picture = BinaryField(required=False, limit=65536)
    email = EmailField(required=False)
    mobile = StringField(required=False)
    phone = StringField(required=False)
    address = DocumentField(required=False, t=Address)
    language = StringField(required=False, multiple=True)
    social = DocumentField(required=False, t=Social, multiple=True)


class PersonProfile(Profile, PersonMixin):
    """Short summary."""
    type = TypeField(value=DocType.PROF_PERSON)
    gender = ChoiceField(required=False, choices=["man", "woman", "undefined"])
    born = DateField(required=False)
    names = StringField(required=False, multiple=True)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.PROF_PERSON)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Profile,
            UpdatedMixin,
            PersonProfile,
            PersonMixin,
        ]
        self._check_validate(validate)
        return True


class MinistryProfile(Profile, MinistryMixin):
    """Short summary."""
    type = TypeField(value=DocType.PROF_MINISTRY)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.PROF_MINISTRY)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Profile,
            UpdatedMixin,
            MinistryProfile,
            MinistryMixin,
        ]
        self._check_validate(validate)
        return True


class ChurchProfile(Profile, ChurchMixin):
    """Short summary."""
    type = TypeField(value=DocType.PROF_CHURCH)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.PROF_CHURCH)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Profile,
            UpdatedMixin,
            ChurchProfile,
            ChurchMixin,
        ]
        self._check_validate(validate)
        return True
