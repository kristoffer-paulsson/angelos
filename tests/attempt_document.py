import datetime
import uuid


class Field:
    def __init__(self, value=None, required=True, multiple=False):
        self.initial_value = value
        self._required = required
        self._multiple = multiple

    def validate(self, value):
        if self._required and not bool(value):
            return False
        if not self._multiple:
            if isinstance(value, list):
                return False


class UuidField(Field):
    def validate(self, value):
        err = False
        err = not Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, uuid.UUID):
                try:
                    uuid.UUID(str(v))
                except TypeError:
                    err = True
        return not err


class DateField(Field):
    def validate(self, value):
        err = False
        err = not Field.validate(self, value)

        if not isinstance(value, list):
            value = [value]

        for v in value:
            if not isinstance(v, datetime.date):
                try:
                    datetime.date.fromisoformat(str(v))
                except TypeError:
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


class DocumentMeta(type):
    def __new__(self, name, bases, namespace):
        fields = {}
        for name, field in namespace.items():
            if isinstance(field, Field):
                fields[name] = field

        ns = namespace.copy()
        for name in fields.keys():
            del ns[name]

        ns['_fields'] = fields
        return super().__new__(self, name, bases, ns)


class DocumentBase(metaclass=DocumentMeta):
    id = UuidField(required=True)
    created = DateField(required=True)
    expires = DateField(required=True)
    type = StringField(required=True)

    def __init__(self, nd={}):
        self.__readonly = False
        for name, field in self._fields.items():
            setattr(self, name, field.initial_value)

        for key, value in nd.items():
            setattr(self, key, value)

        self.populate()

        if bool(self.signature):
            self.__readonly = True

    def __setattr__(self, key, value):
        if key in self._fields:
            if self._fields[key].validate(value):
                super().__setattr__(key, value)
            else:
                raise AttributeError(
                    'Invalid value "{}" for field "{}"'.format(value, key))
        else:
            raise AttributeError('Unknown field "{}"'.format(key))

    def populate(self):
        if not self.id:
            self.id = uuid.uuid4()

        if not self.created:
            self.created = datetime.date.today()

        if not self.expires:
            self.expires = (datetime.date.today() +
                            datetime.timedelta(13*365/12))

    def export(self):
        nd = {}
        for name in self._fields.keys():
            nd[name] = getattr(self, name)

        return nd
