from .test_field import BaseTestField

from libangelos.error import FieldInvalidRegex
from libangelos.document.model import RegexField


class TestRegexField(BaseTestField):
    field = RegexField
    type = str
    type_gen = "Hello, world!"

    regex_success = list()
    regex_failure = list()

    def _test_regex(self):
        for s in self.regex_success:
            try:
                instance = self.field(**self.keywords)
                instance.validate(s, "test")
            except Exception as e:
                self.fail(e)
        for f in self.regex_failure:
            with self.assertRaises(FieldInvalidRegex) as context:
                instance = self.field(**self.keywords)
                instance.validate(f, "test")

    def test_validate(self):
        try:
            self._test_required()
            self._test_multiple()
            self._test_types()
            self._test_regex()
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