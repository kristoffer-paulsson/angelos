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
from unittest import TestCase


class TestEntryRecord(TestCase):
    def test_meta_unpack(self):
        self.fail()

    def test_dir(self):
        self.fail()

    def test_link(self):
        self.fail()

    def test_file(self):
        self.fail()


class TestEntryRegistry(TestCase):
    def test__init_tree(self):
        self.fail()


class TestPathRecord(TestCase):
    def test_meta_unpack(self):
        self.fail()

    def test_path(self):
        self.fail()


class TestPathRegistry(TestCase):
    def test__init_tree(self):
        self.fail()


class TestListingRecord(TestCase):
    def test_meta_unpack(self):
        self.fail()


class TestListingRegistry(TestCase):
    def test__init_tree(self):
        self.fail()


class TestFileObject(TestCase):
    def test__close(self):
        self.fail()

    def test_fileno(self):
        self.fail()


class TestDelete(TestCase):
    pass


class TestHierarchyTraverser(TestCase):
    def test_path(self):
        self.fail()


class TestFileSystemStreamManager(TestCase):
    def test__setup(self):
        self.fail()

    def test__open(self):
        self.fail()

    def test__close(self):
        self.fail()

    def test_resolve_path(self):
        self.fail()

    def test_create_entry(self):
        self.fail()

    def test_update_entry(self):
        self.fail()

    def test_delete_entry(self):
        self.fail()

    def test_change_parent(self):
        self.fail()

    def test_change_name(self):
        self.fail()

    def test_open(self):
        self.fail()

    def test_release(self):
        self.fail()

    def test_traverse_hierarchy(self):
        self.fail()
