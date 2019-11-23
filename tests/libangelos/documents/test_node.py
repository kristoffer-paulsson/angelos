from ipaddress import IPv4Address
from unittest import TestCase

from libangelos.error import DocumentNoLocation
from libangelos.document.domain import Node, Location


class TestNode(TestCase):
    def setUp(self):
        self.instance = self._prepare_node()

    def tearDown(self):
        del self.instance

    def _prepare_node(self, location=Location()):
        return Node(nd={
            "role": "server",
            "location": location
        })

    def test__check_location(self):
        with self.assertRaises(DocumentNoLocation) as context:
            self.instance._check_location()

        try:
            self.instance = self._prepare_node(Location(nd={"hostname": ["example.com"]}))
            self.instance._check_location()

            self.instance = self._prepare_node(Location(nd={"ip":  [IPv4Address("127.0.0.1")]}))
            self.instance._check_location()

            self.instance = self._prepare_node(Location(nd={
                "ip": [IPv4Address("127.0.0.1")],
                "hostname": ["example.com"]
            }))
            self.instance._check_location()
        except Exception as e:
            self.fail(e)

    def test_apply_rules(self):
        try:
            self.instance = self._prepare_node(Location(nd={"hostname": ["example.com"]}))
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)
