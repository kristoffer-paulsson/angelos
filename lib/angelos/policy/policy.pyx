# cython: language_level=3
"""Baseclasses for policies."""
from ..utils import Util
from ..document.entities import Entity, PrivateKeys, Keys


class Policy:
    """Abstract baseclass for all policies."""
    pass


class SignPolicy(Policy):
    """Baseclass for signing policies."""

    def __init__(self, entity, privkeys, keys):
        """Init with Entity, PrivateKeys and Keys."""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(keys, Keys)

        self.__entity = entity
        self.__privkeys = privkeys
        self.__keys = keys

    @property
    def entity(self):
        """Entity readonly property."""
        return self.__entity

    @property
    def privkeys(self):
        """PrivateKeys readonly property."""
        return self.__privkeys

    @property
    def keys(self):
        """Public Keys readonly property."""
        return self.__keys


class VerifyPolicy(Policy):
    """Baseclass for verifying policies."""

    def __init__(self, entity, keys):
        """Init with Entity and Keys."""
        Util.is_type(entity, Entity)
        Util.is_type(keys, Keys)

        self.__entity = entity
        self.__keys = keys
        self._exception = None

    @property
    def entity(self):
        """Entity readonly property."""
        return self.__entity

    @property
    def keys(self):
        """Public Keys readonly property."""
        return self.__keys

    @property
    def exc(self):
        """Exception return readonly property."""
        return self._exception
