# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
Model module.

Contains the document model. A document is made up of a number of fields.
All fields are self-validating. Also all classes based on the BaseDocument can
implement validation.
"""
import base64
import datetime
import ipaddress
import logging
import re
import uuid
from abc import ABC
from typing import Any, Union, Callable, Type

from libangelos.error import Error
from libangelos.utils import Util


class Field(ABC):
    """Base class for all fields.

    Implements basic functionality for fields such as support for init value
    or function, multiple values, whether required and validation checks
    thereof.

    Parameters
    ----------
    value : Any
        Preconfigured value.
    required : bool
        Whether the field is required or not.
    multiple : bool
        Whether the field allows multiple values.
    init : Callable
        Initializing method to be used.

    Attributes
    ----------
    value
        Same as parameter.
    required
        Same as parameter.
    multiple
        Same as parameter.
    init
        Same as parameter.

    """
    TYPES = ()

    def __init__(
            self,
            value: Any = None,
            required: bool = True,
            multiple: bool = False,
            init: Callable = None,
    ):
        """Initialize basic field functionality."""
        self.value = value
        self.required = required
        self.multiple = multiple
        self.init = init

    def _check_required(self, value: Any, name: str) -> bool:
        if self.required and not bool(value):
            raise Util.exception(Error.FIELD_NOT_SET, {"field": name})
        return True

    def _check_multiple(self, value: Any, name: str) -> bool:
        if not self.multiple and isinstance(value, list):
            raise Util.exception(
                Error.FIELD_NOT_MULTIPLE,
                {"type": type(self), "value": value, "field": name},
            )
        if self.multiple and not isinstance(value, (list, type(None))):
            raise Util.exception(
                Error.FIELD_IS_MULTIPLE,
                {"type": type(self), "value": value, "field": name},
            )
        return True

    def _check_types(self, value: Any, name: str) -> bool:
        for v in value if isinstance(value, list) else [value]:
            if not type(v) in (self.TYPES + (type(None),)):
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {
                        "expected": str(self.TYPES),
                        "current": type(v),
                        "field": name,
                    },
                )
        return True

    def validate(self, value: Any, name: str) -> bool:
        """Validate according to basic field functionality.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name)
        ])

    def from_bytes(self, v: bytes) -> Any:
        """Abstract to restore field from bytes.

        Parameters
        ----------
        v : bytes
            Value representation in bytes.

        Returns
        -------
        Any
            Returns restored field.

        """
        raise NotImplementedError()

    def str(self, v: Any) -> str:
        """Abstract for converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        raise NotImplementedError()

    def bytes(self, v: Any) -> bytes:
        """Abstract for converting value to bytes.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        bytes
            Value in bytes representation.

        """
        raise NotImplementedError()

    def yaml(self, v: Any) -> str:
        """Converting value to YAML string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value as YAML formatted string.

        """
        raise NotImplementedError()
        # return v


def conv_dont(f: Field, v: Any) -> Any:
    """None conversion activator.

    Parameters
    ----------
    f : Field
        Dummy argument for compatibility.
    v : any
        Value not to be converted.

    Returns
    -------
    Any
        Returns the value unaltered.

    """
    return v

def conv_str(f: Field, v: Any) -> str:
    """Str conversion activator.

    Parameters
    ----------
    f : Field
        Field type for conversion.
    v : Any
        Value to be converted.

    Returns
    -------
    str
        String representation of value.

    """
    return f.str(v) if v else ""

def conv_bytes(f: Field, v: Any) -> bytes:
    """Bytes conversion activator.

    Parameters
    ----------
    f : Field
        Field type for conversion.
    v : Any
        Value to be converted.

    Returns
    -------
    bytes
        Bytes representation of value.

    """
    return f.bytes(v) if v else b""

def conv_yaml(f: Field, v: Any) -> str:
    """YAML conversion activator.

    Parameters
    ----------
    f : Field
        Field type for conversion.
    v : Any
        Value to be converted.

    Returns
    -------
    str
        YAML formatted string representation of value or None.

    """
    return f.yaml(v) if v else None


class DocumentMeta(type):
    """
    Meta implementation of Document.

    Implements accumulation of all field into one namespace.
    """

    def __new__(mcs, name: str, bases: tuple, namespace: dict):
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
        return super().__new__(mcs, name, bases, ns)


class BaseDocument(metaclass=DocumentMeta):
    """Field magic behind the scenes.

    Implements basic field handling and some export and validation logic.

    Parameters
    ----------
    nd : dict
        Dicrtionary of initial values.
    strict : bool
        Strict validation of attributes, throws exception.

    Attributes
    ----------
    _fields : dict
        Internal holder of the Field classes used.

    """

    def __init__(self, nd: dict = dict(), strict: bool = True):
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
        if key not in self._fields:
            raise AttributeError('Unknown field "%s"'.format(key))
        if not self._fields[key].validate(value, key):
            raise AttributeError(
                'Invalid value "%s" for field "%s"'.format(value, key)
            )
        object.__setattr__(self, key, value)


    @classmethod
    def build(cls: DocumentMeta, data: dict) -> DocumentMeta:
        """Build document from dictionary, takes dict or list of dicts.

        Parameters
        ----------
        cls : DocumentMeta
            class type to build.
        data : dict
            data representation to be populated.

        Returns
        -------
        type
            Polupated document.

        """
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

    def export(self, c=conv_dont) -> dict:
        """Export a document as a dictionary.

        Fields can be converted during export into String or Bytes.

        Parameters
        ----------
        c : type
            Convertion activator to be used.

        Returns
        -------
        dict
            Dictionary representation with converted values.

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
        """Export values converted to string.

        Returns
        -------
        dict
            Dictionary with string representation of values.

        """
        return self.export(conv_str)

    def export_bytes(self):
        """Export values converted to bytes

        Returns
        -------
        dict
            Dictionary with bytes representation of values.

        """
        return self.export(conv_bytes)

    def export_yaml(self):
        """Export values converted to string in YAML format.

        Returns
        -------
        dict
            Dictionary with string representation of values as YAML.

        """
        return self.export(conv_yaml)

    def _check_fields(self):
        """Validate all fields individually in the document."""
        for name in self._fields.keys():
            self._fields[name].validate(getattr(self, name), name)

    def apply_rules(self) -> bool:
        """Apply all rules on BaseDocument level.

        Returns
        -------
        bool
            Result of validation.

        """
        self._check_fields()
        return True

    def validate(self) -> bool:
        """Abstract document validator.

        Should be implemented by all final document implementations.

        Returns
        -------
        bool
            Description of returned object.

        """
        raise NotImplementedError()


class DocumentField(Field):
    """Field that holds one or several Documents as field.

    Parameters
    ----------
    value : Any
        Preconfigured value.
    required : bool
        Whether the field is required or not.
    multiple : bool
        Whether the field allows multiple values.
    init : Callable
        Initializing method to be used.
    doc_class : Type[BaseDocument]
        Set a type to be accepted in particular.

    Attributes
    ----------
    type : Any
        Document type allowed.

    """
    TYPES = ()

    def __init__(
            self,
            value: Any = None,
            required: bool = True,
            multiple: bool = False,
            init: Callable = None,
            doc_class: Type[BaseDocument] = BaseDocument
    ):
        Field.__init__(self, value, required, multiple, init)
        self.type = doc_class

    def _check_document(self, value: Any, name: str) -> bool:
        for v in value if isinstance(value, list) else [value]:
            if isinstance(v, self.type):
                 v.apply_rules()
            elif isinstance(v, type(None)):
                 pass
            else:
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {
                        "expected": type(self.type),
                        "current": type(v),
                        "field": name,
                    },
                )
        return True

    def validate(self, value: Any, name: str) -> bool:
        """Validate DocType and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_document(value, name)
        ])

    def from_bytes(self, v: Union[bytes, dict]) -> Any:
        """Restore field from bytes.

        Parameters
        ----------
        v : bytes
            Value representation in bytes.

        Returns
        -------
        Any
            Returns restored field.

        """
        return self.type.build(v) if isinstance(v, (bytes, dict)) else None


class UuidField(Field):
    """UUID field."""
    TYPES = (uuid.UUID,)

    def validate(self, value: Any, name: str) -> bool:
        """Validate data type as UUID and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ])

    def from_bytes(self, v: bytes) -> Any:
        """Restore field from bytes.

        Parameters
        ----------
        v : bytes
            Value representation in bytes.

        Returns
        -------
        Any
            Returns restored field.

        """
        return uuid.UUID(bytes=v) if v else None

    def str(self, v: Any) -> str:
        """Converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        return str(v)

    def bytes(self, v: Any) -> bytes:
        """Converting value to bytes.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        bytes
            Value in bytes representation.

        """
        return v.bytes

    def yaml(self, v: Any) -> str:
        """Converting value to YAML string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value as YAML formatted string.

        """
        return str(v)


class IPField(Field):
    """IP address field."""
    TYPES = (ipaddress.IPv4Address, ipaddress.IPv6Address)

    def validate(self, value: Any, name: str) -> bool:
        """Validate data type as IPvXAddress and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ])

    def from_bytes(self, v: bytes) -> Any:
        """Restore field from bytes.

        Parameters
        ----------
        v : bytes
            Value representation in bytes.

        Returns
        -------
        Any
            Returns restored field.

        """
        length = len(v)
        if length == 0:
            return None
        elif length == 4:
            return ipaddress.IPv4Address(v)
        elif length == 8:
            return ipaddress.IPv6Address(v)
        else:
            raise TypeError(
                "Not bytes of length 4 or 8. %s %s" % (length, v)
            )

    def str(self, v: Any) -> str:
        """Converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        return str(v)

    def bytes(self, v: Any) -> bytes:
        """Abstract for converting value to bytes.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        bytes
            Value in bytes representation.

        """
        if isinstance(v, ipaddress.IPv4Address):
            return int(v).to_bytes(4, byteorder="big")
        if isinstance(v, ipaddress.IPv6Address):
            return int(v).to_bytes(8, byteorder="big")
        else:
            raise TypeError("Arbitrary size: %s" % len(v))

    def yaml(self, v: Any) -> str:
        """Converting value to YAML string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value as YAML formatted string.

        """
        return str(v)


class DateField(Field):
    """Date field."""
    TYPES = (datetime.date,)

    def validate(self, value: Any, name: str) -> bool:
        """Validate field type as Date and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ])

    def from_bytes(self, v: bytes) -> Any:
        """Restore field from bytes.

        Parameters
        ----------
        v : bytes
            Value representation in bytes.

        Returns
        -------
        Any
            Returns restored field.

        """
        return datetime.date.fromisoformat(v.decode()) if v else None

    def str(self, v: Any) -> str:
        """Converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        return v.isoformat()

    def bytes(self, v: Any) -> bytes:
        """Abstract for converting value to bytes.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        bytes
            Value in bytes representation.

        """
        return v.isoformat().encode()

    def yaml(self, v: Any) -> str:
        """Converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        return v.isoformat()


class DateTimeField(Field):
    """Date and time field."""
    TYPES = (datetime.datetime,)

    def validate(self, value: Any, name: str) -> bool:
        """Validate field type as DateTime and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ])

    def from_bytes(self, v: bytes) -> Any:
        """Restore field from bytes.

        Parameters
        ----------
        v : bytes
            Value representation in bytes.

        Returns
        -------
        Any
            Returns restored field.

        """
        return (
            datetime.datetime.fromisoformat(v.decode()) if v else None
        )

    def str(self, v: Any) -> str:
        """Converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        return v.isoformat()

    def bytes(self, v: Any) -> bytes:
        """Abstract for converting value to bytes.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        bytes
            Value in bytes representation.

        """
        return v.isoformat().encode()

    def yaml(self, v: Any) -> str:
        """Converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        return v.isoformat()


class TypeField(Field):
    """Document type field"""
    TYPES = (int,)

    def validate(self, value: Any, name: str) -> bool:
        """Validate field type as Int and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ])

    def from_bytes(self, v: bytes) -> Any:
        """Restore field from bytes.

        Parameters
        ----------
        v : bytes
            Value representation in bytes.

        Returns
        -------
        Any
            Returns restored field.

        """
        return int.from_bytes(v, byteorder="big") if v else None

    def str(self, v: Any) -> str:
        """Converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        return str(v)

    def bytes(self, v: Any) -> bytes:
        """Abstract for converting value to bytes.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        bytes
            Value in bytes representation.

        """
        return int(v).to_bytes(4, byteorder="big")

    def yaml(self, v: Any) -> str:
        """Converting value to YAML string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value as YAML formatted string.

        """
        return str(v)


class BinaryField(Field):
    """Binary or bytes field.

    Parameters
    ----------
    value : Any
        Preconfigured value.
    required : bool
        Whether the field is required or not.
    multiple : bool
        Whether the field allows multiple values.
    init : Callable
        Initializing method to be used.
    limit : int
        Max bytes limit for field.

    Attributes
    ----------
    limit

    """
    TYPES = (bytes,)

    def __init__(
            self,
            value: Any = None,
            required: bool = True,
            multiple: bool = False,
            init: Callable = None,
            limit: int = 1024
    ):
        Field.__init__(self, value, required, multiple, init)
        self.limit = limit

    def _check_limit(self, value: Any, name: str) -> bool:
        for v in value if isinstance(value, list) else [value]:
            if not isinstance(v, type(None)) and len(v) > self.limit:
                raise Util.exception(
                    Error.FIELD_BEYOND_LIMIT,
                    {"limit": self.limit, "size": len(v), "field": name},
                )
        return True

    def validate(self, value: Any, name: str) -> bool:
        """Validate field type as Bytes and within limits and inherited
        validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name),
            self._check_limit(value, name)
        ])

    def from_bytes(self, v: bytes) -> Any:
        """Restore field from bytes.

        Parameters
        ----------
        v : bytes
            Value representation in bytes.

        Returns
        -------
        Any
            Returns restored field.

        """
        return v if v else None

    def str(self, v: Any) -> str:
        """Converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        return base64.standard_b64encode(v).decode("utf-8")

    def bytes(self, v: Any) -> bytes:
        """Abstract for converting value to bytes.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        bytes
            Value in bytes representation.

        """
        return v

    def yaml(self, v: Any) -> str:
        """Converting value to YAML string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value as YAML formatted string.

        """
        return base64.standard_b64encode(v).decode("utf-8")


class SignatureField(BinaryField):
    """Signature field.

    Parameters
    ----------
    value : Any
        Preconfigured value.
    required : bool
        Whether the field is required or not.
    multiple : bool
        Whether the field allows multiple values.
    init : Callable
        Initializing method to be used.
    limit : int
        Max bytes limit for field.

    Attributes
    ----------
    redo : type
        Description of attribute `redo`.
    limit

    """
    def __init__(
            self,
            value: Any = None,
            required: bool = True,
            multiple: bool = False,
            init: Callable = None,
            limit: int = 1024
    ):
        BinaryField.__init__(self, value, required, multiple, init, limit)
        self.redo = False

    def validate(self, value: Any, name: str) -> bool:
        """Validate field type as String and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            True if self.redo else self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name),
            self._check_limit(value, name)
        ])


class StringField(Field):
    """String field."""
    TYPES = (str,)

    def validate(self, value: Any, name: str) -> bool:
        """Validate field type as String and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ])

    def from_bytes(self, v: bytes) -> Any:
        """Restore field from bytes.

        Parameters
        ----------
        v : bytes
            Value representation in bytes.

        Returns
        -------
        Any
            Returns restored field.

        """
        # return str(v, "utf-8") if v else None
        return v.decode() if v else None

    def str(self, v: Any) -> str:
        """Converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        return v

    def bytes(self, v: Any) -> bytes:
        """Abstract for converting value to bytes.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        bytes
            Value in bytes representation.

        """
        return v.encode()

    def yaml(self, v: Any) -> str:
        """Converting value to string.

        Parameters
        ----------
        v : Any
            Value to be converted.

        Returns
        -------
        str
            Value in string representation.

        """
        return v


class ChoiceField(StringField):
    """Choice field.

    Parameters
    ----------
    value : Any
        Preconfigured value.
    required : bool
        Whether the field is required or not.
    multiple : bool
        Whether the field allows multiple values.
    init : Callable
        Initializing method to be used.
    choices : list
        List of available choices.

    Attributes
    ----------
    choices

    """
    def __init__(
            self,
            value: Any = None,
            required: bool = True,
            multiple: bool = False,
            init: Callable = None,
            choices: list = list(),
    ) -> object:
        Field.__init__(self, value, required, multiple, init)
        if not all(isinstance(n, str) for n in choices):
            raise TypeError()
        self.choices = choices

    def _check_choices(self, value: Any, name: str) -> bool:
        for v in value if isinstance(value, list) else [value]:
            if not isinstance(v, type(None)) and v not in self.choices:
                raise Util.exception(
                    Error.FIELD_INVALID_CHOICE,
                    {"expected": self.choices, "current": v},
                )
        return True

    def validate(self, value: Any, name: str) -> bool:
        """Validate field type as String and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name),
            self._check_choices(value, name)
        ])


class RegexField(StringField):
    """Email field.

    Parameters
    ----------
    value : Any
        Preconfigured value.
    required : bool
        Whether the field is required or not.
    multiple : bool
        Whether the field allows multiple values.
    init : Callable
        Initializing method to be used.

    Attributes
    ----------
    REGEX : str
        Regular expression for validating email.

    """
    REGEX = ("^(.*)$",)

    def __init__(
            self,
            value: Any = None,
            required: bool = True,
            multiple: bool = False,
            init: Callable = None
    ):
        Field.__init__(self, value, required, multiple, init)

    def _check_regex(self, value: Any, name: str) -> bool:
        for v in value if isinstance(value, list) else [value]:
            if not isinstance(v, type(None)) and not bool(
                    re.match(self.REGEX[0], v)
            ):
                raise Util.exception(
                    Error.FIELD_INVALID_REGEX, {"value": v, "field": name}
                )
        return True

    def validate(self, value: Any, name: str) -> bool:
        """Validate as Email address and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name),
            self._check_regex(value, name)
        ])


class EmailField(RegexField):
    """Email field.

    Parameters
    ----------
    value : Any
        Preconfigured value.
    required : bool
        Whether the field is required or not.
    multiple : bool
        Whether the field allows multiple values.
    init : Callable
        Initializing method to be used.

    Attributes
    ----------
    REGEX : str
        Regular expression for validating email.

    """

    # Regex from https://emailregex.com
    REGEX = (
        r"""^(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])$""",
    )

    def __init__(
            self,
            value: Any = None,
            required: bool = True,
            multiple: bool = False,
            init: Callable = None
    ):
        Field.__init__(self, value, required, multiple, init)

    def validate(self, value: Any, name: str) -> bool:
        """Validate as Email address and inherited validation logic.

        Parameters
        ----------
        value : Any
            Value to be validated.
        name : str
            Name of the field.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name),
            self._check_regex(value, name)
        ])
