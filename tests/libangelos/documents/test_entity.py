from unittest import TestCase

from libangelos.document.entities import Entity


class TestEntity(TestCase):
    def setUp(self):
        self.instance = Entity()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()
