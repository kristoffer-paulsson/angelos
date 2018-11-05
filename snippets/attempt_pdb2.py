import datetime
from playhouse.sqlite_ext import (
    Proxy, SqliteDatabase, Model, FixedCharField, TimestampField,
    DateField, CharField, TextField, UUIDField)


class PersonDatabase:
    def __init__(self, path):
        database = SqliteDatabase(path)
        self.BaseModel._meta.database.initialize(database)

        with database:
            database.create_tables([self.Keys])

    class BaseModel(Model):
        class Meta:
            database = Proxy()

    class Keys(BaseModel):
        created_at = TimestampField(
            utc=True, null=False, default=datetime.datetime.now)
        expires_at = TimestampField(utc=True, null=False)
        created = DateField(null=False)
        expires = DateField(null=False)
        id = UUIDField(null=False, primary_key=True)
        issuer = UUIDField(null=False)
        pubkey: FixedCharField(max_length=64, null=False)
        signature: TextField(null=False)
        type = CharField(default='cert.keys', null=False)
        verkey: FixedCharField(max_length=64, null=False)


db = PersonDatabase('test.db')
