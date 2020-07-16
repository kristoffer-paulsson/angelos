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

from libangelos.validation import BasePolicyApplier, PolicyMixin, \
    PolicyValidator, PolicyPerformer, PolicyException, policy, evaluate, PolicyBreachException


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