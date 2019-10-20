# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
Model module.

Contains the document model. A document is made up of a number of fields.
All fields are selfvalidating. Also all classes based on the BaseDocument can
implement validation.
"""
import re
import datetime
import uuid
import ipaddress
import base64
import logging

from ..utils import Util
from ..error import Error, ModelException


class Field:
    """Short summary.

    Parameters
    ----------
    value : type
        Description of parameter `value`.
    required : type
        Description of parameter `required`.
    multiple : type
        Description of parameter `multiple`.
    init : type
        Description of parameter `init`.

    Attributes
    ----------
    value
    required
    multiple
    init

    """
    """
    Base class for all fields.

    Implements basic functionality for fields such as support for init value
    or function, multiple values, whether required and validation checks
    thereof.
    """

    def __init__(self, value=None, required=True, multiple=False, init=None):
        """Initialize basic field functionality."""
        self.value = value
        self.required = required
        self.multiple = multiple
        self.init = init

    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate according to basic field functionality."""
        if self.required and not bool(value):
            logging.debug('Field with "required" not set. (%s)' % value)
            raise Util.exception(Error.FIELD_NOT_SET, {"field": name})

        if not self.multiple and isinstance(value, list):
            logging.debug('Field not "multiple" but list. (%s)' % value)
            raise Util.exception(
                Error.FIELD_NOT_MULTIPLE,
                {"type": type(self), "value": value, "field": name},
            )
        if self.multiple and not isinstance(value, (list, type(None))):
            logging.debug('Field "multiple" but not list. (%s)' % value)
            raise Util.exception(
                Error.FIELD_IS_MULTIPLE,
                {"type": type(self), "value": value, "field": name},
            )
        return True

    def from_bytes(self, v):
        """Abstract to restore field from bytes."""
        raise NotImplementedError()

    def str(self, v):
        """Short summary.

        Parameters
        ----------
        v : type
            Description of parameter `v`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Abstract for converting value to string."""
        raise NotImplementedError()

    def bytes(self, v):
        """Short summary.

        Parameters
        ----------
        v : type
            Description of parameter `v`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Abstract for converting value to bytes."""
        raise NotImplementedError()

    def yaml(self, v):
        """Short summary.

        Parameters
        ----------
        v : type
            Description of parameter `v`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Abstract for converting value to bytes."""
        return v


def conv_dont(f, v):
    """Short summary.

    Parameters
    ----------
    f : type
        Description of parameter `f`.
    v : type
        Description of parameter `v`.

    Returns
    -------
    type
        Description of returned object.

    """
    """None convertion activator."""
    return v


def conv_str(f, v):
    """Short summary.

    Parameters
    ----------
    f : type
        Description of parameter `f`.
    v : type
        Description of parameter `v`.

    Returns
    -------
    type
        Description of returned object.

    """
    """Str convertion activator."""
    return f.str(v) if v else ""


def conv_bytes(f, v):
    """Short summary.

    Parameters
    ----------
    f : type
        Description of parameter `f`.
    v : type
        Description of parameter `v`.

    Returns
    -------
    type
        Description of returned object.

    """
    """Bytes convertion activator."""
    return f.bytes(v) if v else b""


def conv_yaml(f, v):
    """Short summary.

    Parameters
    ----------
    f : type
        Description of parameter `f`.
    v : type
        Description of parameter `v`.

    Returns
    -------
    type
        Description of returned object.

    """
    """Bytes convertion activator."""
    return f.yaml(v) if v else None


class DocumentMeta(type):
    """
    Meta implementation of Document.

    Implements accumulation of all field into one namespace.
    """

    def __new__(self, name, bases, namespace):
        """Create new class."""
        fields = {}
        for base in bases:
            if "_fields" in base.__dict__:
                fields = {**fields, **base.__dict__["_fields"]}

        for fname, field in namespace.items():
            if isinstance(field, Field):
                fields[fname] = field

        ns = namespace.copy()
        for fname in fields.keys():
            if fname in ns:
                del ns[fname]

        ns["_fields"] = fields
        return super().__new__(self, name, bases, ns)


class BaseDocument(metaclass=DocumentMeta):
    """Short summary.

    Parameters
    ----------
    nd : type
        Description of parameter `nd`.
    strict : type
        Description of parameter `strict`.

    Attributes
    ----------
    _fields : type
        Description of attribute `_fields`.

    """
    """
    Field magic behind the scenes.

    Implements basic field handling and some export and validation logic.
    """

    def __init__(self, nd={}, strict=True):
        """
        Initialize a document.

        Receives a dictionary of values and populates the fields.
        """
        for name, field in self._fields.items():
            object.__setattr__(
                self,
                name,
                field.init()
                if (bool(field.init) and not bool(field.value))
                else field.value,
            )

        for key, value in nd.items():
            try:
                setattr(self, key, value)
            except AttributeError as e:
                if strict:
                    raise e

    def __setattr__(self, key, value):
        """
        Set a field.

        Sets a field and validates transparently.
        """
        if key in self._fields:
            try:
                if self._fields[key].validate(value, key):
                    object.__setattr__(self, key, value)
                else:
                    raise AttributeError(
                        'Invalid value "%s" for field "%s"'.format(value, key)
                    )
            except ModelException:
                pass
        else:
            raise AttributeError('Unknown field "%s"'.format(key))

    @classmethod
    def build(cls, data):
        """Short summary.

        Parameters
        ----------
        cls : type
            Description of parameter `cls`.
        data : type
            Description of parameter `data`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Build document from dictionary, takes dict or list of dicts."""
        doc = {}
        logging.debug("Exporting document %s" % type(cls))

        for name, field in cls._fields.items():
            value = data[name]
            logging.debug("%s, %s, %s" % (type(field), name, value))

            if not field.multiple:
                doc[name] = field.from_bytes(value)
            elif isinstance(value, type(None)):
                doc[name] = []
            else:
                item_list = []
                for item in value:
                    item_list.append(field.from_bytes(item))
                doc[name] = item_list
        return cls(nd=doc, strict=False)

    def export(self, c=conv_dont):
        """Short summary.

        Parameters
        ----------
        c : type
            Description of parameter `c`.

        Returns
        -------
        type
            Description of returned object.

        """
        """
        Export a document as a dictionary.

        Fields can be converted during export into String or Bytes.
        """
        nd = {}
        logging.debug("Exporting document %s" % type(self))

        for name, field in self._fields.items():
            value = getattr(self, name)
            logging.debug("%s, %s, %s" % (type(field), name, value))

            if not field.multiple:
                nd[name] = (
                    c(field, value)
                    if not isinstance(value, BaseDocument)
                    else value.export(c)
                )
            elif isinstance(value, type(None)):
                nd[name] = []
            else:
                item_list = []
                for item in value:
                    item_list.append(
                        c(field, item)
                        if not isinstance(item, BaseDocument)
                        else item.export(c)
                    )
                nd[name] = item_list
        return nd

    def export_str(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return self.export(conv_str)

    def export_bytes(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return self.export(conv_bytes)

    def export_yaml(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return self.export(conv_yaml)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate all fields."""
        for name in self._fields.keys():
            self._fields[name].validate(getattr(self, name), name)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        """
        Abstract document validator.

        Should be implemented by all final document implementations.
        """
        raise NotImplementedError()


class DocumentField(Field):
    """Short summary.

    Parameters
    ----------
    value : type
        Description of parameter `value`.
    required : type
        Description of parameter `required`.
    multiple : type
        Description of parameter `multiple`.
    init : type
        Description of parameter `init`.
    t : type
        Description of parameter `t`.

    Attributes
    ----------
    type : type
        Description of attribute `type`.

    """
    """Field that holds one or several Documents as field."""

    def __init__(
        self, value=None, required=True, multiple=False, init=None, t=None
    ):
        Field.__init__(self, value, required, multiple, init)
        """Set a type to be accepted in particular"""
        self.type = t

    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate DocType and inherited validation logic."""
        Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if isinstance(v, (BaseDocument, self.type)):
                v._validate()
            elif not isinstance(v, type(None)):
                logging.debug("Field is not BaseDocument but %s" % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {
                        "expected": type(BaseDocument),
                        "current": type(v),
                        "field": name,
                    },
                )

        return True

    def from_bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        return self.type.build(value) if value else None


class UuidField(Field):
    """Short summary."""
    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate data type as UUID and inherited validation logic."""
        Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (uuid.UUID, type(None))):
                logging.debug("Field is not UUID but %s" % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {
                        "expected": "uuid.UUID",
                        "current": type(v),
                        "field": name,
                    },
                )
        return True

    def from_bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        return uuid.UUID(bytes=value) if value else None

    def str(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Str converter."""
        return str(value)

    def bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Bytes converter."""
        return value.bytes

    def yaml(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """YAML converter."""
        return str(value)


class IPField(Field):
    """Short summary."""
    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate data type as IPvXAddress and inherited validation logic."""
        Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(
                v, (ipaddress.IPv4Address, ipaddress.IPv6Address, type(None))
            ):
                logging.debug("Field is not IPaddress but %s" % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {
                        "expected": "ipaddress.IPv[4|6]Address",
                        "current": type(v),
                        "field": name,
                    },
                )
        return True

    def from_bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        length = len(value)
        if length == 0:
            return None
        elif length == 4:
            return ipaddress.IPv4Address(value)
        elif length == 8:
            return ipaddress.IPv6Address(value)
        else:
            raise TypeError(
                "Not bytes of length 4 or 8. %s %s" % (length, value)
            )

    def str(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Str converter."""
        return str(value)

    def bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Bytes converter."""
        if isinstance(value, ipaddress.IPv4Address):
            return int(value).to_bytes(4, byteorder="big")
        if isinstance(value, ipaddress.IPv6Address):
            return int(value).to_bytes(8, byteorder="big")
        else:
            raise TypeError("Arbitrary size: %s" % len(value))

    def yaml(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """YAML converter."""
        return str(value)


class DateField(Field):
    """Short summary."""
    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate field type as Date and inherited validation logic."""
        Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (datetime.date, type(None))):
                logging.debug("Field is not datetime.date but %s" % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {
                        "expected": "datetime.date",
                        "current": type(v),
                        "field": name,
                    },
                )
        return True

    def from_bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        return datetime.date.fromisoformat(value.decode()) if value else None

    def str(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Str converter."""
        return value.isoformat()

    def bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Bytes converter."""
        return value.isoformat().encode()


class DateTimeField(Field):
    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate field type as DateTime and inherited validation logic."""
        Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (datetime.datetime, type(None))):
                logging.debug("Field is not datetime.date but %s" % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {
                        "expected": "datetime.date",
                        "current": type(v),
                        "field": name,
                    },
                )
        return True

    def from_bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        return (
            datetime.datetime.fromisoformat(value.decode()) if value else None
        )

    def str(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Str converter."""
        return value.isoformat()

    def bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Bytes converter."""
        return value.isoformat().encode()


class StringField(Field):
    """Short summary."""
    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate field type as String and inherited validation logic."""
        Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            # if not isinstance(v, (str, bytes, type(None))):
            if not isinstance(v, (str, type(None))):
                logging.debug('Field is not "str" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {"expected": "str", "current": type(v), "field": name},
                )
        return True

    def from_bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        return str(value, "utf-8") if value else None

    def str(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Str converter."""
        return value

    def bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Bytes converter."""
        return value.encode()


class TypeField(Field):
    """Short summary."""
    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate field type as Int and inherited validation logic."""
        Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (int, type(None))):
                logging.debug('Field is not "int" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {"expected": "int", "current": type(v), "field": name},
                )
        return True

    def from_bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        return int.from_bytes(value, byteorder="big") if value else None

    def str(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Str converter."""
        return str(value)

    def bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Bytes converter."""
        return int(value).to_bytes(4, byteorder="big")

    def yaml(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """YAML converter."""
        return int(value)


class BinaryField(Field):
    """Short summary.

    Parameters
    ----------
    value : type
        Description of parameter `value`.
    required : type
        Description of parameter `required`.
    multiple : type
        Description of parameter `multiple`.
    init : type
        Description of parameter `init`.
    limit : type
        Description of parameter `limit`.

    Attributes
    ----------
    limit

    """
    def __init__(
        self, value=None, required=True, multiple=False, init=None, limit=1024
    ):
        Field.__init__(self, value, required, multiple, init)
        self.limit = limit

    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """
        Validate field type as Bytes and within limits
        and inherited validation logic.
        """
        Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (bytes, type(None))):
                logging.debug('Field is not "bytes" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {"expected": "bytes", "current": type(v), "field": name},
                )

            if not isinstance(v, type(None)) and len(v) > self.limit:
                logging.debug(
                    "Field beyond limit %s but %s" % (self.limit, len(v))
                )
                raise Util.exception(
                    Error.FIELD_BEYOND_LIMIT,
                    {"limit": self.limit, "size": len(v), "field": name},
                )
        return True

    def from_bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        return value if value else None

    def str(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Str converter."""
        return base64.standard_b64encode(value).decode("utf-8")

    def bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Bytes converter."""
        return value

    def yaml(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """YAML converter."""
        return base64.standard_b64encode(value).decode("utf-8")


class SignatureField(BinaryField):
    """Short summary.

    Parameters
    ----------
    value : type
        Description of parameter `value`.
    required : type
        Description of parameter `required`.
    multiple : type
        Description of parameter `multiple`.
    init : type
        Description of parameter `init`.
    limit : type
        Description of parameter `limit`.

    Attributes
    ----------
    redo : type
        Description of attribute `redo`.
    limit

    """
    def __init__(
        self, value=None, required=True, multiple=False, init=None, limit=1024
    ):
        Field.__init__(self, value, required, multiple, init)
        self.limit = limit
        self.redo = False

    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate field type as String and inherited validation logic."""
        if not self.redo:
            Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (bytes, type(None))):
                logging.debug('Field is not "bytes" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {"expected": "bytes", "current": type(v), "field": name},
                )

            if not isinstance(v, type(None)) and len(v) > self.limit:
                logging.debug(
                    "Field beyond limit %s but %s" % (self.size, len(v))
                )
                raise Util.exception(
                    Error.FIELD_BEYOND_LIMIT,
                    {"limit": self.limit, "size": len(v), "field": name},
                )
        return True


class ChoiceField(Field):
    """Short summary.

    Parameters
    ----------
    value : type
        Description of parameter `value`.
    required : type
        Description of parameter `required`.
    multiple : type
        Description of parameter `multiple`.
    init : type
        Description of parameter `init`.
    choices : type
        Description of parameter `choices`.

    Attributes
    ----------
    choices

    """
    def __init__(
        self, value=None, required=True, multiple=False, init=None, choices=[]
    ):
        Field.__init__(self, value, required, multiple, init)
        if not all(isinstance(n, str) for n in choices):
            raise TypeError()
        self.choices = choices

    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate field type as String and inherited validation logic."""
        Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, type(None)) and v not in self.choices:
                logging.debug("Field is not valid choice but %s" % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_CHOICE,
                    {"expected": self.choices, "current": v},
                )
        return True

    def from_bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        return value.decode() if value else None

    def str(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Str converter."""
        return value

    def bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Bytes converter."""
        return value.encode()


class EmailField(Field):
    """Short summary.

    Parameters
    ----------
    value : type
        Description of parameter `value`.
    required : type
        Description of parameter `required`.
    multiple : type
        Description of parameter `multiple`.
    init : type
        Description of parameter `init`.
    choices : type
        Description of parameter `choices`.

    Attributes
    ----------
    EMAIL_REGEX : type
        Description of attribute `EMAIL_REGEX`.
    choices

    """
    EMAIL_REGEX = (
        "^[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,4})$"
    )  # noqa E501

    def __init__(
        self, value=None, required=True, multiple=False, init=None
    ):
        Field.__init__(self, value, required, multiple, init)

    def validate(self, value, name):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.
        name : type
            Description of parameter `name`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Validate as Email address and inherited validation logic."""
        Field.validate(self, value, name)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (str, type(None))):
                logging.debug('Field is not "str" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {"expected": "str", "current": type(v), "field": name},
                )

            if not isinstance(v, type(None)) and not bool(
                re.match(EmailField.EMAIL_REGEX, v)
            ):
                logging.debug("Field is not valid email but %s" % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_EMAIL, {"email": v, "field": name}
                )
        return True

    def from_bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        return value.decode() if value else None

    def str(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Str converter."""
        return value

    def bytes(self, value):
        """Short summary.

        Parameters
        ----------
        value : type
            Description of parameter `value`.

        Returns
        -------
        type
            Description of returned object.

        """
        """Bytes converter."""
        return value.encode()
