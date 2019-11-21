import random

from .test_field import BaseTestField

from libangelos.error import FieldInvalidChoice
from libangelos.document.model import ChoiceField


class TestChoiceField(BaseTestField):
    field = ChoiceField
    keywords = {
        "choices": ["banana", "apple", "orange"]
    }
    type = str
    type_gen = "orange"

    def _test_choices(self):
        choices = self.keywords["choices"] + ["grape", "pear", "pineapple"]
        random.shuffle(choices)
        for c in choices:
            if c in self.keywords["choices"]:
                try:
                    instance = self.field(**self.keywords)
                    instance.validate(c, "test")
                except Exception as e:
                    self.fail(e)
            else:
                with self.assertRaises(FieldInvalidChoice) as context:
                    instance = self.field(**self.keywords)
                    instance.validate(c, "test")

    def test_validate(self):
        try:
            self._test_required()
            self._test_multiple()
            self._test_types()
            self._test_choices()
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