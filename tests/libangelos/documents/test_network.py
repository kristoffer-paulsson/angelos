import uuid

from ipaddress import IPv4Address
from unittest import TestCase

from libangelos.error import DocumentNoHost
from libangelos.document.domain import Network, Host


class TestNetwork(TestCase):
    def setUp(self):
        self.instance = self._prepare_network()

    def tearDown(self):
        del self.instance

    def _prepare_network(self, host=Host(nd={"node": uuid.uuid4()})):
        return Network(nd={
            "domain": uuid.uuid4(),
            "hosts": [host]
        })

    def test__check_host(self):
        with self.assertRaises(DocumentNoHost) as context:
            self.instance._check_host()

        try:
            self.instance = self._prepare_network(Host(nd={
                "node": uuid.uuid4(),
                "hostname": ["example.com"]}))
            self.instance._check_host()

            self.instance = self._prepare_network(Host(nd={
                "node": uuid.uuid4(),
                "ip":  [IPv4Address("127.0.0.1")]}))
            self.instance._check_host()

            self.instance = self._prepare_network(Host(nd={
                "node": uuid.uuid4(),
                "ip": [IPv4Address("127.0.0.1")],
                "hostname": ["example.com"]
            }))
            self.instance._check_host()
        except Exception as e:
            self.fail(e)

    def test_apply_rules(self):
        try:
            self.instance = self._prepare_network(Host(nd={
                "node": uuid.uuid4(),
                "hostname": ["example.com"]}))
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)