#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
import uuid
from ipaddress import IPv4Address
from unittest import TestCase

from angelos.document.domain import Host, Location, Domain, Node, Network
from angelos.document.document import DocumentError


class TestHost(TestCase):
    def setUp(self):
        self.instance = Host()

    def tearDown(self):
        del self.instance


class TestLocation(TestCase):
    def setUp(self):
        self.instance = Location()

    def tearDown(self):
        del self.instance


class TestDomain(TestCase):
    def setUp(self):
        self.instance = Domain()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


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
        with self.assertRaises(DocumentError) as context:
            self.instance._check_location()

        self.instance = self._prepare_node(Location(nd={"hostname": ["example.com"]}))
        self.instance._check_location()

        self.instance = self._prepare_node(Location(nd={"ip":  [IPv4Address("127.0.0.1")]}))
        self.instance._check_location()

        self.instance = self._prepare_node(Location(nd={
            "ip": [IPv4Address("127.0.0.1")],
            "hostname": ["example.com"]
        }))
        self.instance._check_location()

    def test_apply_rules(self):
        self.instance = self._prepare_node(Location(nd={"hostname": ["example.com"]}))
        self.assertTrue(self.instance.apply_rules())


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
        with self.assertRaises(DocumentError) as context:
            self.instance._check_host()

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

    def test_apply_rules(self):
        self.instance = self._prepare_network(Host(nd={
            "node": uuid.uuid4(),
            "hostname": ["example.com"]}))
        self.assertTrue(self.instance.apply_rules())