import datetime
import uuid
from unittest import TestCase

from libangelos.document.messages import Note
from libangelos.document.misc import StoredLetter
from libangelos.error import DocumentWrongID


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
        with self.assertRaises(DocumentWrongID) as context:
            self.instance._check_document_id()

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)