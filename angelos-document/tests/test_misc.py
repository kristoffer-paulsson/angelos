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
import datetime
import uuid
from unittest import TestCase

from angelos.document.messages import Note
from angelos.document.misc import StoredLetter
from angelos.document.document import DocumentError


class TestStoredLetter(TestCase):
    def setUp(self):
        message = Note(nd={
            "posted": datetime.datetime.now()
        })
        self.instance = StoredLetter(nd={
            "id" : message.id,
            "message": message
        })

    def tearDown(self):
        del self.instance

    def test_check_document_id(self):
        try:
            self.instance._check_document_id()
        except Exception as e:
            self.fail(e)

        self.instance.message.id = uuid.uuid4()
        with self.assertRaises(DocumentError) as context:
            self.instance._check_document_id()

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)