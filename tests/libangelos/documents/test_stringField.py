from .test_field import BaseTestField

from libangelos.document.model import StringField


class TestStringField(BaseTestField):
    field = StringField
    type = str
    type_gen = "Hello, world!"

    def test_validate(self):
        try:
            self._test_required()
            self._test_multiple()
            self._test_types()
        except Exception as e:
            self.fail(e)

    def test_from_bytes(self):
        try:
            self._test_bytes_wstr()
        except Exception as e:
            self.fail(e)

    def test_str(self):
        try:
            self._test_str()
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
