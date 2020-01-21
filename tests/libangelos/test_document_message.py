from unittest import TestCase

from libangelos.document.messages import Attachment, Message, Note, Instant, Mail, Share, Report


class TestAttachment(TestCase):
    def setUp(self):
        self.instance = Attachment()

    def tearDown(self):
        del self.instance


class TestMessage(TestCase):
    def setUp(self):
        self.instance = Message()

    def tearDown(self):
        del self.instance


class TestNote(TestCase):
    def setUp(self):
        self.instance = Note()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)


class TestInstant(TestCase):
    def setUp(self):
        self.instance = Instant()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)


class TestMail(TestCase):
    def setUp(self):
        self.instance = Mail()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)


class TestShare(TestCase):
    def setUp(self):
        self.instance = Share()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)


class TestReport(TestCase):
    def setUp(self):
        self.instance = Report()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)
