# cython: language_level=3
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
from ..error import Error


class Field:
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

    def validate(self, value):
        """Validate according to basic field functionality."""
        if self.required and not bool(value):
            logging.debug('Field with "required" not set. (%s)' % value)
            raise Util.exception(Error.FIELD_NOT_SET)

        if not self.multiple and isinstance(value, list):
            logging.debug('Field not "multiple" but list. (%s)' % value)
            raise Util.exception(Error.FIELD_NOT_MULTIPLE, {
                'type': type(self),
                'value': value,
            })
        if self.multiple and not isinstance(value, (list, type(None))):
            logging.debug('Field "multiple" but not list. (%s)' % value)
            raise Util.exception(Error.FIELD_IS_MULTIPLE, {
                'type': type(self),
                'value': value,
            })
        return True

    def from_bytes(self, v):
        """Abstract to restore field from bytes."""
        raise NotImplementedError()

    def str(self, v):
        """Abstract for converting value to string."""
        raise NotImplementedError()

    def bytes(self, v):
        """Abstract for converting value to bytes."""
        raise NotImplementedError()

    def yaml(self, v):
        """Abstract for converting value to bytes."""
        return v


def conv_dont(f, v):
    """None convertion activator."""
    return v


def conv_str(f, v):
    """Str convertion activator."""
    return f.str(v) if v else ''


def conv_bytes(f, v):
    """Bytes convertion activator."""
    return f.bytes(v) if v else b''


def conv_yaml(f, v):
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
            if '_fields' in base.__dict__:
                fields = {**fields, **base.__dict__['_fields']}

        for fname, field in namespace.items():
            if isinstance(field, Field):
                fields[fname] = field

        ns = namespace.copy()
        for fname in fields.keys():
            if fname in ns:
                del ns[fname]

        ns['_fields'] = fields
        return super().__new__(self, name, bases, ns)


class BaseDocument(metaclass=DocumentMeta):
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
            object.__setattr__(self, name, field.init() if (
                bool(field.init) and not bool(field.value)) else field.value)

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
            if self._fields[key].validate(value):
                object.__setattr__(self, key, value)
            else:
                raise AttributeError(
                    'Invalid value "%s" for field "%s"'.format(value, key))
        else:
            raise AttributeError('Unknown field "%s"'.format(key))

    @classmethod
    def build(cls, data):
        params = {}

        for item in data.keys():
            if data[item] is list:
                nl = []
                for value in data[item]:
                    nl.append(cls._fields[item].from_bytes(value))
                params[item] = nl
            else:
                params[item] = cls._fields[item].from_bytes(data[item])
        return cls(nd=params)

    def export(self, c=conv_dont):
        """
        Export a document as a dictionary.

        Fields can be converted during export into String or Bytes.
        """
        nd = {}
        logging.debug('Exporting document %s' % type(self))

        for name, field in self._fields.items():
            value = getattr(self, name)
            logging.debug('%s, %s, %s' % (type(field), name, value))

            if not field.multiple:
                nd[name] = c(field, value) if not isinstance(
                    value, BaseDocument) else value.export(c)
            elif isinstance(value, type(None)):
                nd[name] = []
            else:
                item_list = []
                for item in value:
                    item_list.append(c(field, item) if not isinstance(
                        item, BaseDocument) else item.export(c))
                nd[name] = item_list
        return nd

    def export_str(self):
        return self.export(conv_str)

    def export_bytes(self):
        return self.export(conv_bytes)

    def export_yaml(self):
        return self.export(conv_yaml)

    def _validate(self):
        """Validate all fields."""
        for name in self._fields.keys():
            self._fields[name].validate(getattr(self, name))
        return True

    def validate(self):
        """
        Abstract document validator.

        Should be implemented by all final document implementations.
        """
        raise NotImplementedError()


class DocumentField(Field):
    """Field that holds one or several Documents as field."""

    def __init__(self, value=None, required=True,
                 multiple=False, init=None, t=None):
        Field.__init__(self, value, required, multiple, init)
        """Set a type to be accepted in particular"""
        self.type = t

    def validate(self, value):
        """Validate DocType and inherited validation logic."""
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if isinstance(v, (BaseDocument, self.type)):
                v._validate()
            elif not isinstance(v, type(None)):
                logging.debug('Field is not BaseDocument but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': type(BaseDocument), 'current': type(v)})

        return True

    def from_bytes(self, value):
        return self.t.build(value) if value else None


class UuidField(Field):
    def validate(self, value):
        """Validate data type as UUID and inherited validation logic."""
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (uuid.UUID, type(None))):
                logging.debug('Field is not UUID but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'uuid.UUID', 'current': type(v)})
        return True

    def from_bytes(self, value):
        return uuid.UUID(bytes=value) if value else None

    def str(self, value):
        """Str converter."""
        return str(value)

    def bytes(self, value):
        """Bytes converter."""
        return value.bytes

    def yaml(self, value):
        """YAML converter."""
        return str(value)


class IPField(Field):
    def validate(self, value):
        """Validate data type as IPvXAddress and inherited validation logic."""
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (
                    ipaddress.IPv4Address, ipaddress.IPv6Address, type(None))):
                logging.debug('Field is not IPaddress but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'ipaddress.IPv[4|6]Address',
                     'current': type(v)})
        return True

    def from_bytes(self, value):
        length = len(value)
        if length == 0:
            return None
        elif length == 4:
            return ipaddress.IPv4Address(value)
        elif length == 8:
            return ipaddress.IPv6Address(value)
        else:
            raise TypeError('Not bytes of length 4 or 8')

    def str(self, value):
        """Str converter."""
        return str(value)

    def bytes(self, value):
        """Bytes converter."""
        if isinstance(value, ipaddress.IPv4Address):
            return int(value).to_bytes(4, byteorder='big')
        if isinstance(value, ipaddress.IPv6Address):
            return int(value).to_bytes(8, byteorder='big')
        else:
            raise TypeError()


class DateField(Field):
    def validate(self, value):
        """Validate field type as Date and inherited validation logic."""
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (datetime.date, type(None))):
                logging.debug('Field is not datetime.date but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'datetime.date', 'current': type(v)})
        return True

    def from_bytes(self, value):
        return datetime.date.fromisoformat(value.decode()) if value else None

    def str(self, value):
        """Str converter."""
        return value.isoformat()

    def bytes(self, value):
        """Bytes converter."""
        print('Date2bytes:', value.isoformat().encode())
        return value.isoformat().encode()


class StringField(Field):
    def validate(self, value):
        """Validate field type as String and inherited validation logic."""
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            # if not isinstance(v, (str, bytes, type(None))):
            if not isinstance(v, (str, type(None))):
                logging.debug('Field is not "str" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'str', 'current': type(v)})
        return True

    def from_bytes(self, value):
        return value.decode() if value else None

    def str(self, value):
        """Str converter."""
        return value

    def bytes(self, value):
        """Bytes converter."""
        return value.encode()


class TypeField(Field):
    def validate(self, value):
        """Validate field type as Int and inherited validation logic."""
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (int, type(None))):
                logging.debug('Field is not "int" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'int', 'current': type(v)})
        return True

    def from_bytes(self, value):
        return int.from_bytes(value, byteorder='big') if value else None

    def str(self, value):
        """Str converter."""
        return str(value)

    def bytes(self, value):
        """Bytes converter."""
        return bytes([value])

    def yaml(self, value):
        """YAML converter."""
        return int(value)


class BinaryField(Field):
    def __init__(self, value=None, required=True,
                 multiple=False, init=None, limit=1024):
        Field.__init__(self, value, required, multiple, init)
        self.limit = limit

    def validate(self, value):
        """
        Validate field type as Bytes and within limits
        and inherited validation logic.
        """
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (bytes, type(None))):
                logging.debug('Field is not "bytes" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'bytes', 'current': type(v)})

            if not isinstance(v, type(None)) and len(v) > self.limit:
                logging.debug('Field beyond limit %s but %s' % (
                    self.limit, len(v)))
                raise Util.exception(
                    Error.FIELD_BEYOND_LIMIT,
                    {'limit': self.limit, 'size': len(v)})
        return True

    def from_bytes(self, value):
        return value if value else None

    def str(self, value):
        """Str converter."""
        return base64.standard_b64encode(value).decode('utf-8')

    def bytes(self, value):
        """Bytes converter."""
        return value

    def yaml(self, value):
        """YAML converter."""
        return base64.standard_b64encode(value).decode('utf-8')


class SignatureField(BinaryField):
    def __init__(self, value=None, required=True,
                 multiple=False, init=None, limit=1024):
        Field.__init__(self, value, required, multiple, init)
        self.limit = limit
        self.redo = False

    def validate(self, value):
        """Validate field type as String and inherited validation logic."""
        if not self.redo:
            Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (bytes, type(None))):
                logging.debug('Field is not "bytes" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'bytes', 'current': type(v)})

            if not isinstance(v, type(None)) and len(v) > self.limit:
                logging.debug('Field beyond limit %s but %s' % (
                    self.size, len(v)))
                raise Util.exception(
                    Error.FIELD_BEYOND_LIMIT,
                    {'limit': self.limit, 'size': len(v)})
        return True


class ChoiceField(Field):
    def __init__(self, value=None, required=True,
                 multiple=False, init=None, choices=[]):
        Field.__init__(self, value, required, multiple, init)
        if not all(isinstance(n, str) for n in choices):
            raise TypeError()
        self.choices = choices

    def validate(self, value):
        """Validate field type as String and inherited validation logic."""
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, type(None)) and v not in self.choices:
                logging.debug('Field is not valid choice but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_CHOICE,
                    {'expected': self.choices, 'current': v})
        return True

    def from_bytes(self, value):
        return value.decode() if value else None

    def str(self, value):
        """Str converter."""
        return value

    def bytes(self, value):
        """Bytes converter."""
        return value.encode()


class EmailField(Field):
    EMAIL_REGEX = '^[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,4})$'  # noqa E501

    def __init__(self, value=None, required=True,
                 multiple=False, init=None, choices=[]):
        Field.__init__(self, value, required, multiple, init)
        self.choices = choices

    def validate(self, value):
        """Validate as Email address and inherited validation logic."""
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (str, type(None))):
                logging.debug('Field is not "str" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'str', 'current': type(v)})

            if not isinstance(v, type(None)) and not bool(
                    re.match(EmailField.EMAIL_REGEX, v)):
                logging.debug('Field is not valid email but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_EMAIL, {'email': v})
        return True

    def from_bytes(self, value):
        return value.decode() if value else None

    def str(self, value):
        """Str converter."""
        return value

    def bytes(self, value):
        """Bytes converter."""
        return value.encode()
