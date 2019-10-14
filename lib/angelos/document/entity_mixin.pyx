# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Entity mixin for shared fields."""
from ..utils import Util
from ..error import Error

from .model import DocumentMeta, ChoiceField, DateField, StringField


class PersonMixin(metaclass=DocumentMeta):
    """Mixin for person specific fields."""

    sex = ChoiceField(choices=["man", "woman", "undefined"])
    born = DateField()
    names = StringField(multiple=True)
    family_name = StringField()
    given_name = StringField()

    def _validate(self):
        # Validate that "given_name" is present in "names"
        if self.given_name not in self.names:
            raise Util.exception(
                Error.DOCUMENT_PERSON_NAMES,
                {"name": self.given_name, "not_in": self.names},
            )
        return True


class MinistryMixin(metaclass=DocumentMeta):
    """Mixin for ministry specific fields."""

    vision = StringField(required=False)
    ministry = StringField()
    founded = DateField()

    def _validate(self):
        return True


class ChurchMixin(metaclass=DocumentMeta):
    """Mixin for church specific fields."""

    founded = DateField()
    city = StringField()
    region = StringField(required=False)
    country = StringField(required=False)

    def _validate(self):
        return True
