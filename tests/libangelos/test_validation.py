#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
import logging
import uuid
from unittest import TestCase

from libangelos.validation import Report, BaseValidator, BaseValidatable, BasePolicyApplier, PolicyMixin, \
    PolicyValidator, PolicyPerformer, PolicyException, policy, evaluate, Journal, PolicyBreachException, journal_ctx


class StubValidator(BaseValidator):
    """Stub validator"""

    def validate_test(self, validatable: BaseValidatable, report: Report) -> bool:
        return self._validator(validatable, report)


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


class StubValidatable(BaseValidatable, BaseValidator):
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
            report = Report(StubValidator())
            validatable = StubSubValidatable("test")
            validatable.apply_rules(report, Report.NULL_IDENTITY)
            self.assertIs(len(report.applied), 3)
            self.assertIs(len(report.failed), 1)

            report = Report(StubValidator())
            validatable = StubSubValidatable("test", True)
            validatable.apply_rules(report, Report.NULL_IDENTITY)
            self.assertIs(len(report.applied), 3)
            self.assertIs(len(report.failed), 2)
        except Exception as e:
            self.fail(e)

    def test_apply_rules(self):
        try:
            with self.assertRaises(TypeError):
                BaseValidatable()

            report = Report(StubValidator())
            validatable = StubValidatable()
            validatable.apply_rules(report, Report.NULL_IDENTITY)
            self.assertIs(len(report.applied), 9)
            self.assertIs(len(report.failed), 4)
        except Exception as e:
            self.fail(e)


class TestBaseValidator(TestCase):
    def test__validator(self):
        try:
            validator = StubValidator()
            report = Report(validator)
            validatable = StubValidatable()
            self.assertFalse(validator.validate_test(validatable, report))
        except Exception as e:
            self.fail(e)

    def test_validate(self):
        try:
            validator = BaseValidator()
            validator.validate()
        except Exception as e:
            self.fail(e)


#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####
    # NEW VALIDATOR FRAMEWORK
#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####


class SubjectStub:
    """Subject to be validated and performed on."""

    def __init__(self):
        self.foo = True
        self.bar = False
        self.baz = None


class FooPolicyStub(PolicyMixin):
    """Stub policy number one"""

    @policy(b'I', 1)
    def apply(self) -> bool:
        if not self._subject.foo:
            raise PolicyException()
        return True


class BarPolicyStub(PolicyMixin):
    """Stub policy number two"""

    @policy(b'I', 2, "FooBarBaz")
    def apply(self) -> bool:
        if self._subject.bar:
            raise PolicyException()
        return True


class BazPolicyStub(PolicyMixin):
    """Stub policy number three"""

    @policy(b'I', 3)
    def apply(self) -> bool:
        if self._subject.baz:
            raise PolicyException()
        return True


class StubValidator(PolicyValidator, FooPolicyStub, BarPolicyStub, BazPolicyStub):

    def __init__(self):
        super().__init__()
        self._subject = None

    def _setup(self):
        pass

    def validate(self, subject: SubjectStub):
        self._subject = subject
        self._applier()

    def _clean(self):
        pass


class StubPerformer(PolicyPerformer, FooPolicyStub, BarPolicyStub, BazPolicyStub):

    def __init__(self):
        super().__init__()
        self._subject = None

    def _setup(self):
        pass

    def perform(self, subject: SubjectStub):
        self._subject = subject
        if self._applier():
            pass
        else:
            pass

    def _clean(self):
        pass


class TestBasePolicyApplier(TestCase):
    def test__applier(self):
        try:
            with self.assertRaises(TypeError):
                BasePolicyApplier()
        except Exception as e:
            self.fail(e)

    def test__setup(self):
        try:
            with self.assertRaises(TypeError):
                BasePolicyApplier()
        except Exception as e:
            self.fail(e)

    def test__clean(self):
        try:
            with self.assertRaises(TypeError):
                BasePolicyApplier()
        except Exception as e:
            self.fail(e)


class TestPolicyMixin(TestCase):
    def test_apply(self):
        try:
            with self.assertRaises(TypeError):
                PolicyMixin()
        except Exception as e:
            self.fail(e)


class TestPolicyValidator(TestCase):
    def test_validate(self):
        try:
            with self.assertRaises(TypeError):
                PolicyValidator()

            subject = SubjectStub()
            validator = StubValidator()

            try:
                validator.validate(subject)
            except PolicyException:
                self.fail("No policy exception expected.")

            with self.assertRaises(PolicyException):
                subject.foo = False
                validator.validate(subject)

        except Exception as e:
            self.fail(e)


class TestPolicyPerformer(TestCase):
    def test_perform(self):
        try:
            with self.assertRaises(TypeError):
                PolicyPerformer()

            subject = SubjectStub()
            performer = StubPerformer()

            try:
                performer.perform(subject)
            except PolicyException:
                self.fail("No policy exception expected.")

            with self.assertRaises(PolicyException):
                subject.foo = False
                performer.perform(subject)

        except Exception as e:
            self.fail(e)


class Test_evaluate(TestCase):
    def test_evaluate(self):
        try:
            subject = SubjectStub()
            subject.foo = False
            validator = StubValidator()

            with self.assertRaises(PolicyBreachException):
                with evaluate("Run unittest") as report:
                    validator.validate(subject)

            try:
                with evaluate("Run unittest"):
                    validator.validate(subject)
            except PolicyBreachException as e:
                print(e)  # Print policy breach

        except Exception as e:
            self.fail(e)


class Test_policy(TestCase):
    def test_policy(self):
        try:
            pass
        except Exception as e:
            self.fail(e)
