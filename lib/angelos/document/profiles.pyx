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
    """Short summary.

    Attributes
    ----------
    co : StringField
        Description of attribute `co`.
    organisation : StringField
        Description of attribute `organisation`.
    department : StringField
        Description of attribute `department`.
    apartment : StringField
        Description of attribute `apartment`.
    floor : StringField
        Description of attribute `floor`.
    building : StringField
        Description of attribute `building`.
    street : StringField
        Description of attribute `street`.
    number : StringField
        Description of attribute `number`.
    area : StringField
        Description of attribute `area`.
    city : StringField
        Description of attribute `city`.
    pobox : StringField
        Description of attribute `pobox`.
    zip : StringField
        Description of attribute `zip`.
    subregion : StringField
        Description of attribute `subregion`.
    region : StringField
        Description of attribute `region`.
    country : StringField
        Description of attribute `country`.
    """
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
    """Short summary.

    Attributes
    ----------
    token : StringField
        Description of attribute `token`.
    service : StringField
        Description of attribute `service`.
    """
    token = StringField()
    service = StringField()


class Profile(Document, UpdatedMixin):
    """Short summary.

    Attributes
    ----------
    picture : BinaryField
        Description of attribute `picture`.
    email : EmailField
        Description of attribute `email`.
    mobile : StringField
        Description of attribute `mobile`.
    phone : StringField
        Description of attribute `phone`.
    address : DocumentField
        Description of attribute `address`.
    language : StringField
        Description of attribute `language`.
    social : DocumentField
        Description of attribute `social`.
    """
    picture = BinaryField(required=False, limit=65536)
    email = EmailField(required=False)
    mobile = StringField(required=False)
    phone = StringField(required=False)
    address = DocumentField(required=False, t=Address)
    language = StringField(required=False, multiple=True)
    social = DocumentField(required=False, t=Social, multiple=True)


class PersonProfile(Profile, PersonMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    gender : ChoiceField
        Description of attribute `gender`.
    born : DateField
        Description of attribute `born`.
    names : StringField
        Description of attribute `names`.
    """
    type = TypeField(value=DocType.PROF_PERSON)
    gender = ChoiceField(required=False, choices=["man", "woman", "undefined"])
    born = DateField(required=False)
    names = StringField(required=False, multiple=True)

    def _validate(self) -> bool:
        """Short summary.

        Returns
        -------
        bool
            Description of returned object.

        """
        self._check_type(DocType.PROF_PERSON)
        return True

    def validate(self) -> bool:
        """Short summary.

        Returns
        -------
        bool
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
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=DocType.PROF_MINISTRY)

    def _validate(self) -> bool:
        """Short summary.

        Returns
        -------
        bool
            Description of returned object.

        """
        self._check_type(DocType.PROF_MINISTRY)
        return True

    def validate(self) -> bool:
        """Short summary.

        Returns
        -------
        bool
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
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=DocType.PROF_CHURCH)

    def _validate(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.PROF_CHURCH)
        return True

    def validate(self) -> bool:
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
