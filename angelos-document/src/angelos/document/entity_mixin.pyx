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
"""Entity mixin for shared fields."""
from angelos.common.policy import policy
from angelos.document.document import DocumentError
from angelos.document.model import DocumentMeta, ChoiceField, DateField, StringField


class PersonMixin(metaclass=DocumentMeta):
    """Mixin for person specific fields.

    Attributes
    ----------
    sex : ChoiceField
        Description of attribute `sex`.
    born : DateField
        Description of attribute `born`.
    names : StringField
        Description of attribute `names`.
    family_name : StringField
        Description of attribute `family_name`.
    given_name : StringField
        Description of attribute `given_name`.
    """
    sex = ChoiceField(choices=["man", "woman", "undefined"])
    born = DateField()
    names = StringField(multiple=True)
    family_name = StringField()
    given_name = StringField()

    @policy(b"C", 29)
    def _check_names(self) -> bool:
        """Check that given name is among names."""
        if self.given_name not in self.names:
            raise DocumentError(
                *DocumentError.DOCUMENT_PERSON_NAMES,
                {"name": self.given_name, "not_in": self.names})
        return True

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_names()
        ])


class MinistryMixin(metaclass=DocumentMeta):
    """Mixin for ministry specific fields.

    Attributes
    ----------
    vision : StringField
        Description of attribute `vision`.
    ministry : StringField
        Description of attribute `ministry`.
    founded : DateField
        Description of attribute `founded`.
    """

    vision = StringField(required=False)
    ministry = StringField()
    founded = DateField()

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return True


class ChurchMixin(metaclass=DocumentMeta):
    """Mixin for church specific fields.

    Attributes
    ----------
    founded : DateField
        Description of attribute `founded`.
    city : StringField
        Description of attribute `city`.
    region : StringField
        Description of attribute `region`.
    country : StringField
        Description of attribute `country`.
    """

    founded = DateField()
    city = StringField()
    region = StringField(required=False)
    country = StringField(required=False)

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return True
