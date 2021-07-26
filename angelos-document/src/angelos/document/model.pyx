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
"""
Model module.

Contains the document model. A document is made up of a number of fields.
All fields are self-validating. Also all classes based on the BaseDocument can
implement validation.
"""
import base64
import datetime
import ipaddress
import itertools
import re
import uuid
from abc import ABC
from typing import Any, Union, Callable, Type

# TODO:
#   Add support for fromisoformat in Python 3.6
#   datetime.date(int(date_str[0:4]), int(date_str[5:7]), int(date_str[8:10]))
from angelos.common.policy import PolicyException, policy


class FieldError(PolicyException):
    """Exception class for errors with fields."""
    FIELD_NOT_SET = ("Required value is not set", 600)
    FIELD_NOT_MULTIPLE = ("Value is list, but not set to multiple", 601)
    FIELD_INVALID_TYPE = ("Value type is invalid", 602)
    FIELD_INVALID_CHOICE = ("Value not among acceptable choices", 603)
    FIELD_INVALID_REGEX = ("Given email not a regular email address", 607)
    FIELD_BEYOND_LIMIT = ("Given data to large", 608)
    FIELD_IS_MULTIPLE = ("Value is not list, but set to multiple", 609)
    FIELDS_ARE_REQUIRED = ("Fields are required.", 615)
    FIELD_UNKNOWN = ("Named field is unknown", 616)
    FIELD_INVALID_DATA = ("Invalid data", 617)


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
        """Initialize basic field functionality.

        Returns:
            :
        """
        self.value = value
        self.required = required
        self.multiple = multiple
        self.init = init

    @policy(b"A", 1)
    def _check_required(self, value: Any, name: str) -> bool:
        """1A-0001: Check that a field marked as required is not empty. Required fields are mandatory."""
        if self.required and not bool(value):
            raise FieldError(*FieldError.FIELD_NOT_SET, {"field": name})
        return True

    @policy(b"A", 2)
    def _check_multiple(self, value: Any, name: str) -> bool:
        """1A-0002: Check that multifield isn't assigned non-list items directly, this goes both ways.
        A multifield must have a list."""
        if not self.multiple and isinstance(value, list):
            raise FieldError(*FieldError.FIELD_NOT_MULTIPLE, {"type": type(self), "value": value, "field": name})
        if self.multiple and not isinstance(value, (list, type(None))):
            raise FieldError(*FieldError.FIELD_IS_MULTIPLE, {"type": type(self), "value": value, "field": name})
        return True

    @policy(b"A", 3)
    def _check_types(self, value: Any, name: str) -> bool:
        """1A-0003: Check that a field is assigned an item of a specified type only.
        The specified item types are required."""
        for v in value if isinstance(value, list) else [value]:
            if not type(v) in (self.TYPES + (type(None),)):
                raise FieldError(
                    *FieldError.FIELD_INVALID_TYPE,
                    {"expected": str(self.TYPES), "current": type(v), "field": name})
        return True

    @policy(b"B", 4, "Field")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0004: Apply mandatory field checks to base field.

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
        if not all([
            self._check_required(value, name),
            self._check_multiple(value, name)
        ]):
            raise PolicyException()
        return True

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

        for field_name, field in namespace.items():
            if isinstance(field, Field):
                fields[field_name] = field

        ns = namespace.copy()
        for field_name in fields.keys():
            if field_name in ns:
                del ns[field_name]

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

        if not self._fields:
            raise FieldError(*FieldError.FIELDS_ARE_REQUIRED)

    def __setattr__(self, key, value):
        """
        Set a field.

        Sets a field and validates transparently.
        """
        if key not in self._fields:
            raise FieldError(*FieldError.FIELD_UNKNOWN, {"name", key})
        if not self._fields[key].validate(value, name=key):
            raise FieldError(*FieldError.FIELD_INVALID_TYPE, {"name": key, "value": value})
        object.__setattr__(self, key, value)

    def __eq__(self, other):
        """Compare two documents.

        If other is another type then its false.
        Else if data exported bytes are equal or not.

        Args:
            other (Any):
                Should be a BaseDocument otherwise False.

        Returns (bool):
            True or False based on equality.

        """
        if not isinstance(other, type(self)):
            return False
        else:
            return self.export_bytes() == other.export_bytes()

    def __hash__(self):
        """Used for dictionary lookup of documents."""
        return hash(tuple(sorted(itertools.chain(self.export_bytes()))))

    # FIXME: Create unittest for this one.
    @classmethod
    def fields(cls) -> tuple:
        """Tuple of all field names."""
        return tuple(cls._fields.keys())

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

        for name, field in cls._fields.items():
            value = data[name]

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

        for name, field in self._fields.items():
            value = getattr(self, name)

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

    @policy(b"C", 5)
    def _check_fields(self) -> bool:
        """Validate all fields individually in the document."""
        for name in self._fields.keys():
            self._fields[name].validate(getattr(self, name), name=name)
        return True

    def apply_rules(self) -> bool:
        """Apply all rules on BaseDocument level.

        Returns
        -------
        bool
            Result of validation.

        """
        return all([
            self._check_fields()
        ])

    # @policy(b"I", 0)
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

    @policy(b"A", 6)
    def _check_document(self, value: Any, name: str) -> bool:
        """1A-0006: Do validation of all documents."""
        for v in value if isinstance(value, list) else [value]:
            if isinstance(v, self.type):
                v.apply_rules()
            elif isinstance(v, type(None)):
                pass
            else:
                raise FieldError(
                    *FieldError.FIELD_INVALID_TYPE,
                    {"expected": type(self.type), "current": type(v), "field": name})
        return True

    @policy(b"B", 7, "DocumentField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0007: Apply mandatory field checks to document field.

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
        if not all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_document(value, name)
        ]):
            raise PolicyException()
        return True

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
        return self.type.build(v) if v else None


class UuidField(Field):
    """UUID field."""
    TYPES = (uuid.UUID,)

    @policy(b"B", 8, "UuidField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0008: Apply mandatory field checks to uuid field.

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
        if not  all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ]):
            raise PolicyException()
        return True

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

    @policy(b"B", 9, "IPField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0009: Apply mandatory field checks to IP-address field.

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
        if not all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ]):
            raise PolicyException()
        return True

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
            raise FieldError(*FieldError.FIELD_INVALID_DATA, {"length": length, "expected": [4, 8]})

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
            raise FieldError(
                *FieldError.FIELD_INVALID_TYPE,
                {"expected": [ipaddress.IPv4Address, ipaddress.IPv6Address], "type": type(v)})

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

    @policy(b"B", 10, "DateField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0010: Apply mandatory field checks to date field.

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
        if not all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ]):
            raise PolicyException()
        return True

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

    @policy(b"B", 11, "DateTimeField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0011: Apply mandatory field checks to date time field.

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
        if not all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ]):
            raise PolicyException()
        return True

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

    @policy(b"B", 12, "TypeField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0009: Apply mandatory field checks to type field.

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
        if not all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ]):
            raise PolicyException()
        return True

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

    @policy(b"A", 13)
    def _check_limit(self, value: Any, name: str) -> bool:
        """1A-0013: Check that size of bytes is within limit."""
        for v in value if isinstance(value, list) else [value]:
            if not isinstance(v, type(None)) and len(v) > self.limit:
                raise FieldError(
                    *FieldError.FIELD_BEYOND_LIMIT,
                    {"limit": self.limit, "size": len(v), "field": name})
        return True

    @policy(b"B", 14, "BinaryField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0014: Apply mandatory field checks to bytes field.

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
        if not  all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name),
            self._check_limit(value, name)
        ]):
            raise PolicyException()
        return True

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

    @policy(b"B", 15, "SignatureField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0015: Apply mandatory field checks to signature field.

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
        if not all([
            True if self.redo else self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name),
            self._check_limit(value, name)
        ]):
            raise PolicyException()
        return True


class StringField(Field):
    """String field."""
    TYPES = (str,)

    @policy(b"B", 16, "StringField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0016: Apply mandatory field checks to string field.

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
        if not all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name)
        ]):
            raise PolicyException()
        return True

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
            raise FieldError(*FieldError.FIELD_INVALID_TYPE, {"expected": str, "given": choices})
        self.choices = choices

    @policy(b"A", 17)
    def _check_choices(self, value: Any, name: str) -> bool:
        """1A-0017: Check that choice is of available value."""
        for v in value if isinstance(value, list) else [value]:
            if not isinstance(v, type(None)) and v not in self.choices:
                raise FieldError(*FieldError.FIELD_INVALID_CHOICE, {"expected": self.choices, "current": v})
        return True

    @policy(b"B", 18, "ChoiceField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0016: Apply mandatory field checks to choice field.

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
        if not all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name),
            self._check_choices(value, name)
        ]):
            raise PolicyException()
        return True


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

    @policy(b"A", 19)
    def _check_regex(self, value: Any, name: str) -> bool:
        """1A-0019: Check that field value comply with said regular expression."""
        for v in value if isinstance(value, list) else [value]:
            if not isinstance(v, type(None)) and not bool(re.match(self.REGEX[0], v)):
                raise FieldError(*FieldError.FIELD_INVALID_REGEX, {"value": v, "field": name})
        return True

    @policy(b"B", 20, "RegexField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0020: Apply mandatory field checks to regex field.

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
        if not all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name),
            self._check_regex(value, name)
        ]):
            raise PolicyException()
        return True


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
    REGEX : tuple(str)
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

    @policy(b"B", 21, "EmailField")
    def validate(self, value: Any, name: str) -> bool:
        """1B-0021: Apply mandatory field checks to email field.

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
        if not all([
            self._check_required(value, name),
            self._check_multiple(value, name),
            self._check_types(value, name),
            self._check_regex(value, name)
        ]):
            raise PolicyException()
        return True
