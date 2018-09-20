import datetime
from peewee import (
    Proxy, SqliteDatabase, Model, FixedCharField, TimestampField, DateField,
    CharField, TextField, UUIDField, BooleanField, JSONField)


class PersonDatabase:
    def __init__(self, path):
        database = SqliteDatabase(path)
        self.BaseModel._meta.database.initialize(database)

        with database:
            database.create_tables([
                self.Identity, self.Vault, self.DocumentPerson,
                self.DocumentKeys])

    class BaseModel(Model):
        class Meta:
            database = Proxy()

    class Identity(BaseModel):
        id = UUIDField(unique=True, null=False)
        data = JSONField(null=False, default={})
        pk = BooleanField(primary_key=True, null=False, default=True)

    class Person(BaseModel):
        created_at = TimestampField(
            utc=True, null=False, default=datetime.datetime.now)
        expires_at = TimestampField(
            utc=True, null=False,
            default=lambda self: datetime.fromisoformat(
                self.expires).timestamp())
        updated_at = TimestampField(
            utc=True, null=True,
            default=lambda self: datetime.fromisoformat(
                self.updated).timestamp())
        """
        created_at, expires_at and updated_at is database specific, they are
        not part of the document.

        created_at: holds the timestamp when the db record was created.
        expires_at: holds the timestamp of when the document expires, derives
                    from the documents expires
        updated_at: holds the timestamp when the db record was updated
        """
        born = DateField(null=False)
        created = DateField(null=False)
        expires = DateField(null=False)
        family_name = CharField(null=False)
        gender = CharField(null=False, choices={
            'value': ('woman', 'man', 'undefined'),
            'display': ('Woman', 'Man', 'Undefined')
        })
        given_name = CharField(null=False)
        id = UUIDField(primary_key=True, unique=True, null=False)
        issuer = UUIDField(null=False)
        names = CharField(null=False)
        signature = TextField(null=False)
        type = CharField(default='entity.person', null=False)
        updated = DateField(null=True)

    class Keys(BaseModel):
        created_at = TimestampField(
            utc=True, null=False, default=datetime.datetime.now)
        expires_at = TimestampField(
            utc=True, null=False,
            default=lambda self: datetime.fromisoformat(
                self.expires).timestamp())
        """
        created_at and expires_at and is database specific, they are not part
        of the document.

        created_at: holds the timestamp when the db record was created.
        expires_at: holds the timestamp of when the document expires, derives
                    from the documents expires
        """
        created = DateField(null=False)
        expires = DateField(null=False)
        id = UUIDField(primary_key=True, unique=True, null=False)
        issuer = UUIDField(null=False)
        public: FixedCharField(max_length=64, null=False)
        signature: TextField(null=False)
        type = CharField(default='cert.keys', null=False)
        verify: FixedCharField(max_length=64, null=False)
