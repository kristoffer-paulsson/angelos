import datetime
from peewee import (
    Proxy, SqliteDatabase, Model, FixedCharField, TimestampField, DateField,
    CharField, TextField, UUIDField)
from libnacl.dual import DualSecret

TEST_DATA1 = """
---
born: 1981-02-03
created: 2018-09-20
expires: 2019-10-20
family_name: Gustafsson
gender: man
given_name: Herbert
id: 9574902a-46f4-44ad-81a4-eb5713172745
issuer: 9574902a-46f4-44ad-81a4-eb5713172745
names:
- Herbert
- Göran
- Albert
signature: x87KCAtP5BCXmgu4f9CnBLwcgDZtZaayZSkvoLBdoYDvHhbjdp8+PXGyE3Ajz/F7hhPbECcOReqgRLCZ+mjADQ==
type: entity.person
updated: null
...
"""  # noqa E501

TEST_DATA2 = """
---
created: 2018-09-20
expires: 2019-10-20
id: 4a001821-43e8-4053-b158-3891a1d06489
issuer: 9574902a-46f4-44ad-81a4-eb5713172745
public: a5cbfe3235501f3a527eef87e4513465b597b38c0d2e959fe3e964187c1ef252
signature: ZekFAT0JLHNIlWukumOAGI7oEb4nOYyOFxUPWhucqhO6MQfEPSkBQzKfgjjT6mzChGTf3txde3Zk/Y7yzsGZBg==
type: cert.keys
verify: 7139c01d74895b8dc6b72f7b1bdce548bdef49d90780a22f592dd39e68f817df
...
"""  # noqa E501


class PersonDatabase:
    def __init__(self, path):
        database = SqliteDatabase('default.db')
        self.BaseModel._meta.database.initialize(database)

        with database:
            database.create_tables([
                self.Vault, self.DocumentPerson, self.DocumentKeys])

    class BaseModel(Model):
        class Meta:
            database = Proxy()

    class Vault(BaseModel):
        created_at = TimestampField(
            utc=True, null=False, default=datetime.datetime.now)
        expires_at = TimestampField(utc=True, null=False)
        priv = FixedCharField(max_length=64, null=False, unique=True)
        pub = FixedCharField(max_length=64, null=False)
        sign = FixedCharField(max_length=64, null=False, unique=True)
        verify = FixedCharField(max_length=64, null=False)

    def save_to_vault(self, dual):
        obj = dual.for_json()
        self.Vault.create(
            priv=obj['priv'], pub=obj['pub'],
            sign=obj['sign'], verify=obj['verify']
        )

    def load_from_vault(self, id):
        obj = self.Vault.get(id)
        return DualSecret(crypto=obj.priv, sign=obj.sign)

    class DocumentPerson(BaseModel):
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

    class DocumentKeys(BaseModel):
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
