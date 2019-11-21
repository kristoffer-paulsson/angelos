from unittest import TestCase

from libangelos.document.model import BaseDocument


class TestBaseDocument(TestCase):
    def setUp(self):
        self.instance = BaseDocument()

    def tearDown(self):
        del self.instance

    def test_build(self):
        self.fail()

    def test_export(self):
        self.fail()

    def test_export_str(self):
        self.fail()

    def test_export_bytes(self):
        self.fail()

    def test_export_yaml(self):
        self.fail()

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
