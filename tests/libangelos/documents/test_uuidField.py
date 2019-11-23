import uuid

from .test_field import BaseTestField

from libangelos.document.model import UuidField


class TestUuidField(BaseTestField):
    field = UuidField
    type = uuid.UUID
    type_gen = uuid.uuid4()

    def test_validate(self):
        try:
            self._test_required()
            self._test_multiple()
            self._test_types()
        except Exception as e:
            self.fail(e)

    def test_from_bytes(self):
        try:
            self._test_bytes_wint()
        except Exception as e:
            self.fail(e)

    def test_str(self):
        try:
            self._test_str()
        except Exception as e:
            self.fail(e)

    def test_bytes(self):
        try:
            self._test_bytes_wint()
        except Exception as e:
            self.fail(e)

    def test_yaml(self):
        try:
            self._test_yaml()
        except Exception as e:
            self.fail(e)