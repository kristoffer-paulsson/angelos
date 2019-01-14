import datetime
from playhouse.sqlite_ext import (
    Proxy, SqliteDatabase, Model, Field, FixedCharField, TimestampField,
    DateField, CharField, TextField, JSONField, UUIDField)


class StringListField(Field):
    field_type = 'list'

    def db_value(self, value):
        return ' '.join(value)  # convert UUID to hex string.

    def python_value(self, value):
        return list(filter(None, value.strip().split(' ')))


class PersonDatabase:
    def __init__(self, path):
        database = SqliteDatabase(path + '/default.db')
        self.BaseModel._meta.database.initialize(database)

        with database:
            database.create_tables([
                self.Identity, self.Person, self.Keys])

    @staticmethod
    def prepare(obj):
        try:
            if bool(obj['expires']):
                obj['expires_at'] = datetime.datetime.fromisoformat(
                    str(obj['expires'])).timestamp()
        except KeyError:
            pass

        try:
            if bool(obj['updated']):
                obj['updated_at'] = datetime.datetime.fromisoformat(
                    str(obj['updated'])).timestamp()
        except KeyError:
            pass

        return obj

    class BaseModel(Model):
        class Meta:
            database = Proxy()

    class Identity(BaseModel):
        id = UUIDField(null=False, primary_key=True)
        data = JSONField(null=False, default='{}')
        pk = FixedCharField(choices=['i'], unique=True,
                            max_length=1, default='i')

    class Person(BaseModel):
        created_at = TimestampField(
            utc=True, null=False, default=datetime.datetime.now)
        expires_at = TimestampField(utc=True, null=False)
        updated_at = TimestampField(utc=True, null=True)
        """
        created_at, expires_at and updated_at is database specific, they are
        not part of the document.

        created_at: holds the timestamp when the db record was created.
        expires_at: holds the timestamp of when the document expires, derives
                    from the documents expires
        updated_at: holds the timestamp when the db record was updated
        """
        born = DateField(null=False)  # null=False
        created = DateField(null=False)
        expires = DateField(null=False)
        family_name = CharField(null=False)
        gender = CharField(null=False, choices={
            'value': ('woman', 'man', 'undefined'),
            'display': ('Woman', 'Man', 'Undefined')
        })
        given_name = CharField(null=False)
        id = UUIDField(null=False, primary_key=True)
        issuer = UUIDField(null=False)
        names = StringListField(null=False)
        signature = TextField(null=False)
        type = CharField(default='entity.person', null=False)
        updated = DateField(null=True)

    class Keys(BaseModel):
        created_at = TimestampField(
            utc=True, null=False, default=datetime.datetime.now)
        expires_at = TimestampField(utc=True, null=False)
        """
        created_at and expires_at and is database specific, they are not part
        of the document.

        created_at: holds the timestamp when the db record was created.
        expires_at: holds the timestamp of when the document expires, derives
                    from the documents expires
        """
        created = DateField(null=False)
        expires = DateField(null=False)
        id = UUIDField(null=False, primary_key=True)
        issuer = UUIDField(null=False)
        public = FixedCharField(max_length=64, null=False)
        signature = TextField(null=False)
        type = CharField(default='cert.keys', null=False)
        verify = FixedCharField(max_length=64, null=False)
