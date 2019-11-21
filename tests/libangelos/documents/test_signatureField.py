from .test_field import BaseTestField

from libangelos.document.model import SignatureField


class TestSignatureField(BaseTestField):
    field = SignatureField
    type = bytes
    type_gen = b'6\xa9\xa1P\xd8\xd5H\x17\xa2P\x13\xff\xebv\x934'

    def test_validate(self):
        try:
            self._test_required()
            self._test_multiple()
            self._test_types()
            self._test_limit()
        except Exception as e:
            self.fail(e)

    def test_from_bytes(self):
        try:
            self._test_bytes_wstr()
        except Exception as e:
            self.fail(e)

    def test_str(self):
        try:
            self._test_str_wb64()
        except Exception as e:
            self.fail(e)

    def test_bytes(self):
        try:
            self._test_bytes_wstr()
        except Exception as e:
            self.fail(e)

    def test_yaml(self):
        try:
            self._test_yaml()
        except Exception as e:
            self.fail(e)