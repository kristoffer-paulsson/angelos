# cython: language_level=3
"""Module docstring."""
import datetime
from ..utils import Util

from ..document.entities import Entity, Person, Ministry, Church, Keys
from ..document.statements import Statement
from ..document.domain import Domain, Node, Network
from ..document.profiles import Profile
from ..document.envelope import Envelope
from ..document.messages import Message

from .entity import (
    PersonPolicy, MinistryPolicy, ChurchPolicy)
from .crypto import Crypto
from .policy import Policy


class ImportPolicy(Policy):
    def __init__(self, entity, keys):
        Util.is_type(entity, Entity)
        Util.is_type(keys, Keys)

        self.__entity = entity
        self.__keys = keys
        self._exception = None

    def document(self, document):
        Util.is_type(document, (
            Statement, Profile, Domain, Node, Network, Message))
        self._exception = None
        valid = True
        try:
            if datetime.date.today() > document.expires:
                valid = False
            valid = False if not document.validate() else valid
            valid = False if not Crypto.verify(
                document, self.__entity, self.__keys) else valid
        except Exception as e:
            self._exception = e
            valid = False

        return valid

    def envelope(self, envelope):
        Util.is_type(envelope, Envelope)
        self._exception = None
        valid = True
        try:
            if datetime.date.today() > envelope.expires:
                valid = False
            valid = False if not envelope.validate() else valid
            valid = False if not Crypto.verify(
                envelope, self.__entity, self.__keys, exclude=['header']
                ) else valid
        except Exception as e:
            self._exception = e
            valid = False

        return valid


class ImportEntityPolicy(Policy):
    def __init__(self):
        self.__exception = None

    def __validate(self, entity, keys):
        valid = True

        today = datetime.date.today()
        valid = False if entity.expires < today else valid
        valid = False if keys.expires < today else valid

        try:
            valid = False if not entity.validate() else valid
            valid = False if not keys.validate() else valid
            if datetime.date.today() > entity.expires:
                valid = False
        except Exception as e:
            self._exception = e
            valid = False

        valid = False if not Crypto.verify(keys, entity, keys) else valid
        valid = False if not Crypto.verify(entity, entity, keys) else valid

        return valid

    def person(self, entity, keys):
        Util.is_type(entity, Person)
        Util.is_type(keys, Keys)
        return self.__validate(entity, keys)

    def ministry(self, entity, keys):
        Util.is_type(entity, Ministry)
        Util.is_type(keys, Keys)
        return self.__validate(entity, keys)

    def church(self, entity, keys):
        Util.is_type(entity, Church)
        Util.is_type(keys, Keys)
        return self.__validate(entity, keys)


class ImportUpdatePolicy(Policy):
    def __init__(self, entity, keys):
        Util.is_type(entity, Entity)
        Util.is_type(keys, Keys)

        self.__entity = entity
        self.__keys = keys
        self._exception = None

    def keys(self, newkeys):
        Util.is_type(newkeys, Keys)
        self._exception = None
        valid = True
        try:
            valid = False if not newkeys.validate() else valid
            if datetime.date.today() > newkeys.expires:
                valid = False
        except Exception as e:
            self._exception = e
            valid = False

        valid = False if not Crypto.verify(
            newkeys, self.__entity, self.__keys) else valid
        valid = False if not Crypto.verify(
            newkeys, self.__entity, newkeys) else valid

        return valid

    def __dict_cmp(self, entity, fields):
        valid = True

        valid = False if datetime.date.today() > entity.expires else valid
        valid = False if not entity.validate() else valid
        valid = False if not Crypto.verify(
            entity, self.__entity, self.__keys) else valid

        diff = []
        new_exp = entity.export()
        old_exp = self.__entity.export()

        for item in new_exp.keys():
            if new_exp[item] != old_exp[item]:
                diff.append(item)

        if len(set(diff) - set(fields + ['signature', 'updated'])):
            valid = False

        return valid

    def entity(self, entity):
        Util.is_type(entity, type(self.__entity))
        Util.is_type(entity, (Person, Ministry, Church))

        if isinstance(entity, Person):
            fields = PersonPolicy.FIELDS
        elif isinstance(entity, Ministry):
            fields = MinistryPolicy.FIELDS
        elif isinstance(entity, Church):
            fields = ChurchPolicy.FIELDS

        self._exception = None
        try:
            valid = self.__dict_cmp(entity, fields)
        except Exception as e:
            self._exception = e
            valid = False

        return valid
