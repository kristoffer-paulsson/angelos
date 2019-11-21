import random
from .test_field import BaseTestField

from libangelos.document.model import DocumentField
from libangelos.document.document import BaseDocument
from libangelos.error import FieldInvalidType


class TestDocument(BaseDocument):
    pass


class TestDocumentField(BaseTestField):
    field = DocumentField
    type = TestDocument
    type_gen = TestDocument()

    def _test_types(self):
        # DocumentField use custom type handling!
        random.shuffle(self.types)
        for t in self.types:
            if t == self.type:
                try:
                    instance = self.field()
                    instance.validate(self.gen[t], "test")
                except Exception as e:
                    self.fail(e)
            else:
                with self.assertRaises(FieldInvalidType) as context:
                    instance = self.field()
                    instance.validate(self.gen[t], "test")

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()

    def test_from_bytes(self):
        try:
            serialized = self.type().export_bytes()
            instance = self.field(doc_class=TestDocument)
            self.assertIsInstance(
                instance.from_bytes(serialized),
                self.type,
                "Could not restore document from bytes")
        except Exception as e:
            self.fail(e)
