import datetime
import uuid


class Field:
    def __init__(self, value=None, required=True, multiple=False, init=None):
        self.value = value
        self.required = required
        self.multiple = multiple
        self.init = init

    def validate(self, value):
        if self.required and not bool(value):
            return False
        if not self.multiple:
            if isinstance(value, list):
                return False
        return True

    def to_str(self, value):
        return value


class UuidField(Field):
    def validate(self, value):
        err = False
        err = not Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, uuid.UUID):
                err = True
        return not err

    def to_str(self, value):
        return str(value)


class DateField(Field):
    def validate(self, value):
        err = False
        err = not Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, datetime.date):
                err = True
        return not err


class StringField(Field):
    def validate(self, value):
        err = False
        err = not Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not (isinstance(v, str) or bool(str(value))):
                err = True
        return not err


class ChoiceField(Field):
    def __init__(self, value=None, required=True,
                 multiple=False, init=None, choices=[]):
        Field.__init__(self, value, required, multiple, init)
        self.choices = choices

    def validate(self, value):
        err = False
        err = not Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if v not in self.choices:
                err = True
        return not err


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
    def __init__(self, nd={}):
        for name, field in self._fields.items():
            object.__setattr__(self, name, field.init() if (
                bool(field.init) and not bool(field.value)) else field.value)

        for key, value in nd.items():
            setattr(self, key, value)

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
            nd[name] = self._fields[name].to_str(getattr(self, name))
        return nd

    def export_str(self):
        nd = {}
        for name in self._fields.keys():
            attr = self._fields[name].to_str(getattr(self, name))
            if isinstance(attr, list):
                nd[name] = ' '.join(attr)
            else:
                nd[name] = str()
        return nd
