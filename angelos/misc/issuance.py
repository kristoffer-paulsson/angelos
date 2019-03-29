import base64
from ..utils import Util
from ..error import Error
from .model import DocumentMeta, StringField, UuidField


class IssuerMixin:
    def issue(self, issue, private_key, signer):
        data = str(self.id) + issue._data()
        issue.sign(self.id, signer.sign(data))

    def verify(self, issue, signee):
        data = str(self.id) + issue._data()
        if issue.signature != signee.sign(data):
            raise Util.exception(
                Error.ISSUANCE_INVALID_ISSUE,
                {'issuer': self.id, 'issue': issue.id,
                 'public_key': signee.public_key()})


class IssueMixin(metaclass=DocumentMeta):
    signature = StringField()
    issuer = UuidField()

    def data_msg(self):
        concat = ''
        for field, data in sorted(self.export().items()):
            if field in ['signature', 'issuer']:
                continue
            if isinstance(data, list):
                data_str = ''.join(data)
            else:
                data_str = str(data)
            concat += data_str

        return concat

    def sign(self, issuer_id, signature):
        self.issuer = issuer_id
        self.signature = base64.standard_b64encode(signature).decode('utf-8')


class AbstractSigner:
    def __init__(self, private, public):
        self._privk = public
        self._pubk = private

    def sign(self, data):
        raise NotImplementedError()

    def public_key(self):
        return self._pubk
