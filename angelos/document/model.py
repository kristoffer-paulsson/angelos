import re
import datetime
import uuid
import ipaddress

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
            raise Util.exception(Error.FIELD_NOT_SET)
        if not self.multiple:
            if isinstance(value, list):
                raise Util.exception(Error.FIELD_NOT_MULTIPLE)
        return True

    def to_str(self, value):
        return value


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
            except AttributeError:
                if strict:
                    raise

    def __setattr__(self, key, value):
        if key in self._fields:
            if self._fields[key].validate(value):
                object.__setattr__(self, key, value)
            else:
                raise AttributeError(
                    'Invalid value "{0}" for field "{1}"'.format(value, key))
        else:
            raise AttributeError('Unknown field "{0}"'.format(key))

    def export(self):
        nd = {}
        for name in self._fields.keys():
            nd[name] = getattr(self, name)
        return nd

    def export_conf(self):
        nd = {}
        for name in self._fields.keys():
            nd[name] = self._fields[name].to_str(getattr(self, name))
        return nd

    def export_str(self):
        nd = {}
        for name in self._fields.keys():
            attr = self._fields[name].to_str(getattr(self, name))
            if isinstance(attr, list):
                nd[name] = ' '.join(attr)
            else:
                nd[name] = str(attr)
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
            if not isinstance(v, (BaseDocument, type(None))):
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': type(BaseDocument), 'current': type(v)})

            if not isinstance(v, (self.type, type(None))):
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': type(self.type), 'current': type(v)})

            v._validate()
        return True


class UuidField(Field):
    def validate(self, value):
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (uuid.UUID, type(None))):
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'uuid.UUID', 'current': type(v)})
        return True

    def to_str(self, value):
        return str(value)


class IPField(Field):
    def validate(self, value):
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (
                    ipaddress.IPv4Address, ipaddress.IPv6Address, type(None))):
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'ipaddress.IPv[4|6]Address',
                     'current': type(v)})
        return True

    def to_str(self, value):
        return str(value)


class DateField(Field):
    def validate(self, value):
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, (datetime.date, type(None))):
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'datetime.date', 'current': type(v)})
        return True


class StringField(Field):
    def validate(self, value):
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not (isinstance(v, (str, type(None))) or bool(str(v))):
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'str', 'current': type(v)})
        return True


class BytesField(Field):
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
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'bytes', 'current': type(v)})

            if len(v) > self.limit:
                raise Util.exception(
                    Error.FIELD_BEYOND_LIMIT,
                    {'limit': self.limit, 'size': len(v)})
        return True


class ChoiceField(Field):
    def __init__(self, value=None, required=True,
                 multiple=False, init=None, choices=[]):
        Field.__init__(self, value, required, multiple, init)
        self.choices = choices

    def validate(self, value):
        Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if v not in self.choices:
                raise Util.exception(
                    Error.FIELD_INVALID_CHOICE,
                    {'expected': self.choices, 'current': v})
        return True


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
            if not (isinstance(v, (str, type(None))) or bool(str(v))):
                raise Util.exception(
                    Error.FIELD_INVALID_TYPE,
                    {'expected': 'str', 'current': type(v)})

            if not bool(re.match(EmailField.EMAIL_REGEX, v)):
                raise Util.exception(
                    Error.FIELD_INVALID_EMAIL,
                    {'email': v})
        return True
