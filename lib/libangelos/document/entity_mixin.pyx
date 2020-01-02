# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Entity mixin for shared fields."""
from libangelos.utils import Util
from libangelos.error import Error

from libangelos.document.model import DocumentMeta, ChoiceField, DateField, StringField


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

    def _check_names(self):
        """Check that given name is among names."""
        if self.given_name not in self.names:
            raise Util.exception(
                Error.DOCUMENT_PERSON_NAMES,
                {"name": self.given_name, "not_in": self.names},
            )

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_names()
        return True


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

    def apply_rules(self):
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

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return True
