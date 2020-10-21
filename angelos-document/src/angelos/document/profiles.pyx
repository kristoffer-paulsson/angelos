# cython: language_level=3
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
from angelos.document.document import DocType, Document, ChangeableMixin
from angelos.document.entity_mixin import PersonMixin, MinistryMixin, ChurchMixin
from angelos.document.model import BaseDocument, StringField, DateField, ChoiceField, EmailField, BinaryField, DocumentField, TypeField


class Address(BaseDocument):
    """Short summary."""
    care_of = StringField(required=False)
    house = StringField(required=False)
    number = StringField(required=False)
    road = StringField(required=False)
    postcode = StringField(required=False)
    neighborhood = StringField(required=False)
    village = StringField(required=False)
    town = StringField(required=False)
    suburb = StringField(required=False)
    city_district = StringField(required=False)
    city = StringField(required=False)
    county = StringField(required=False)
    county_code = StringField(required=False)
    state_district = StringField(required=False)
    state = StringField(required=False)
    state_code = StringField(required=False)
    region = StringField(required=False)
    province = StringField(required=False)
    island = StringField(required=False)
    country = StringField(required=False)
    country_code = StringField(required=False)
    continent = StringField(required=False)


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


class Profile(Document, ChangeableMixin):
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
    address = DocumentField(required=False, doc_class=Address)
    language = StringField(required=False, multiple=True)
    social = DocumentField(required=False, doc_class=Social, multiple=True)

    def apply_rules(self) -> bool:
        return True


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
    type = TypeField(value=int(DocType.PROF_PERSON))
    sex = ChoiceField(required=False, choices=["man", "woman", "undefined"])
    born = DateField(required=False)
    names = StringField(required=False, multiple=True)

    def changeables(self) -> tuple:
        """Fields that are changeable when updating."""
        return (
            "sex", "born", "names", "family_name", "given_names",
            "picture", "email", "mobile", "phone", "address", "language", "social"
        )

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        bool
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.PROF_PERSON)
        ])


class MinistryProfile(Profile, MinistryMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.PROF_MINISTRY))

    def changeables(self) -> tuple:
        """Fields that are changeable when updating."""
        return (
            "vision", "ministry", "founded",
            "picture", "email", "mobile", "phone", "address", "language", "social"
        )

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        bool
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.PROF_MINISTRY)
        ])


class ChurchProfile(Profile, ChurchMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.PROF_CHURCH))

    def changeables(self) -> tuple:
        """Fields that are changeable when updating."""
        return (
            "founded", "city", "region", "country",
            "picture", "email", "mobile", "phone", "address", "language", "social"
        )

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.PROF_CHURCH)
        ])
