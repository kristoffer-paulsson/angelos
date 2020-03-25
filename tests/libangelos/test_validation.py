import abc
import uuid
from unittest import TestCase

from libangelos.validation import Report, BaseValidator, BaseValidatable


class StubValidator(BaseValidator):
    """Stub validator"""


class StubSubValidatable(BaseValidatable):
    """Stub sub validatable."""

    def __init__(self, name, wrong=False):
        self.__name = name
        self.__wrong = wrong

    def apply_rules(self, report: Report = None, identity: uuid.UUID = None):
        rules = [
            (self._check_something_1, b'I', 1),
            (self._check_something_2, b'I', 2),
            (self._check_something_3, b'I', 3)
        ]
        return self._checker(rules, report, identity, self.__name)

    def _check_something_1(self):
        return True

    def _check_something_2(self):
        raise KeyError("Something wrong 2")

    def _check_something_3(self):
        if self.__wrong:
            raise ValueError("Something wrong 3")
        return True


class StubValidatable(BaseValidatable, StubValidator):
    """Stub validatable."""

    def __init__(self):
        BaseValidatable.__init__(self)
        StubValidator.__init__(self)

        self.__id = uuid.uuid4()
        self.__one = StubSubValidatable("One")
        self.__two = StubSubValidatable("Two", True)

    def apply_rules(self, report: Report = None, identity: uuid.UUID = None):
        rules = [
            (self._check_something_4, b'I', 4),
            (self._check_something_5, b'I', 5),
            (self._check_something_6, b'I', 6)
        ]
        return all((
            self._checker(rules, report, self.__id),
            self.__one.apply_rules(report, self.__id),
            self.__two.apply_rules(report, self.__id)
        ))

    def _check_something_4(self):
        return True

    def _check_something_5(self):
        raise KeyError("Something wrong 5")

    def _check_something_6(self):
        return False


class TestReport(TestCase):
    def test_applied(self):
        try:
            report = Report(StubValidator())
            self.assertEqual(report.applied, set())
            report.record(Report.NULL_IDENTITY, b'I', 0)
            self.assertIs(len(report.applied), 1)
            self.assertIs(len(report.failed), 0)
            self.assertTrue(report)
        except Exception as e:
            self.fail(e)

    def test_failed(self):
        try:
            report = Report(StubValidator())
            self.assertEqual(report.failed, set())
            report.record(Report.NULL_IDENTITY, b'I', 0, True)
            self.assertIs(len(report.applied), 1)
            self.assertIs(len(report.failed), 1)
            self.assertFalse(report)
        except Exception as e:
            self.fail(e)

    def test_record(self):
        try:
            report = Report(StubValidator())
            report.record(Report.NULL_IDENTITY, b'I', 0)
            self.assertEqual(report.applied.pop(), Report.NULL_POLICY)
        except Exception as e:
            self.fail(e)


class TestBaseValidatable(TestCase):
    def test__checker(self):
        try:
            validatable = StubValidatable()
            report = validatable.validate()
            print(report)
        except Exception as e:
            self.fail(e)

    def test_apply_rules(self):
        try:
            pass
        except Exception as e:
            self.fail(e)


class TestBaseValidator(TestCase):
    def test__validator(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    def test_validate(self):
        try:
            pass
        except Exception as e:
            self.fail(e)
