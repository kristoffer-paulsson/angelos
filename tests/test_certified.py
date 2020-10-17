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
import importlib
import logging
import os
import sys
import unittest

TESTS = [
    "document_document",
    "document_domain",
    "document_entities",
    "document_entity_mixin",
    "document_envelope",
    "document_message",
    "document_misc",
    "document_model",
    "document_profiles",
    "document_statements",

    "library_nacl",
    "reactive",
    "validation",
    "archive7_tree",
    "archive7_archive",
    #"replication",
]
TESTS = [
    "replication"
]
PREFIX = "tests.library.test_"

if __name__ == '__main__':
    test = None
    # sys.path.append(os.path.join(os.path.abspath(os.curdir), "lib"))
    sys.path.append(os.path.abspath(os.curdir))
    loader = unittest.TestLoader()
    unittest.TextTestRunner().run(unittest.TestSuite(
        [loader.loadTestsFromModule(importlib.import_module(PREFIX + test)) for test in TESTS]))
