"""Module docstring."""
import re
import datetime
import uuid
import ipaddress
import base64
import logging

from ..utils import Util
from ..error import Error


class Field:
    def __init__(self, value=None, required=True, multiple=False, init=None):
        self.value = value
        self.required = required
        self.multiple = multiple
        self.init = init

    def validate(self, value):
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

    def str(self, v):
        raise NotImplementedError()

    def bytes(self, v):
        raise NotImplementedError()


def conv_dont(f, v):
    return v


def conv_str(f, v):
    return f.str(v) if v else ''


def conv_bytes(f, v):
    return f.bytes(v) if v else b''


class DocumentMeta(type):
    def __new__(self, name, bases, namespace):
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
    def __init__(self, nd={}, strict=True):
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
        if key in self._fields:
            if self._fields[key].validate(value):
                object.__setattr__(self, key, value)
            else:
                raise AttributeError(
                    'Invalid value "%s" for field "%s"'.format(value, key))
        else:
            raise AttributeError('Unknown field "%s"'.format(key))

    def export(self, c=conv_dont):
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

    def _validate(self):
        for name in self._fields.keys():
            self._fields[name].validate(getattr(self, name))
        return True

    def validate(self):
        raise NotImplementedError()


class DocumentField(Field):
    def __init__(self, value=None, required=True,
                 multiple=False, init=None, t=None):
        Field.__init__(self, value, required, multiple, init)
        self.type = t

    def validate(self, value):
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

    def to_str(self, value):
        return value.export_str()

    def to_bytes(self, value):
        return value.export_bytes()


class UuidField(Field):
    def validate(self, value):
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

    def str(self, value):
        return str(value)

    def bytes(self, value):
        return value.bytes


class IPField(Field):
    def validate(self, value):
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

    def str(self, value):
        return str(value)

    def bytes(self, value):
        if isinstance(value, ipaddress.IPv4Address):
            return int(value).to_bytes(4, byteorder='big')
        if isinstance(value, ipaddress.IPv6Address):
            return int(value).to_bytes(8, byteorder='big')
        else:
            raise TypeError()


class DateField(Field):
    def validate(self, value):
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

    def str(self, value):
        return value.isoformat()

    def bytes(self, value):
        return bytes(value.isoformat(), 'utf-8')


class StringField(Field):
    def validate(self, value):
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (str, bytes, type(None))):
                logging.debug('Field is not "str" but %s' % type(v))
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'str', 'current': type(v)})
        return True

    def str(self, value):
        return value

    def bytes(self, value):
        return str(value).encode('utf-8')


class TypeField(Field):
    def validate(self, value):
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

    def str(self, value):
        return str(value)

    def bytes(self, value):
        return bytes([value])


class BinaryField(Field):
    def __init__(self, value=None, required=True,
                 multiple=False, init=None, limit=1024):
        Field.__init__(self, value, required, multiple, init)
        self.limit = limit

    def validate(self, value):
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

    def str(self, value):
        return base64.standard_b64encode(value).decode('utf-8')

    def bytes(self, value):
        return value


class SignatureField(BinaryField):
    def __init__(self, value=None, required=True,
                 multiple=False, init=None, limit=1024):
        Field.__init__(self, value, required, multiple, init)
        self.limit = limit
        self.redo = False

    def validate(self, value):
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

    def str(self, value):
        return value

    def bytes(self, value):
        return bytes(value, 'utf-8')


class EmailField(Field):
    EMAIL_REGEX = '^[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,4})$'  # noqa E501

    def __init__(self, value=None, required=True,
                 multiple=False, init=None, choices=[]):
        Field.__init__(self, value, required, multiple, init)
        self.choices = choices

    def validate(self, value):
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

    def str(self, value):
        return value

    def bytes(self, value):
        return bytes(value, 'utf-8')
