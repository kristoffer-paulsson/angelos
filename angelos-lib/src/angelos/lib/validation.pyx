# cython: language_level=3
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
"""Validation framework.

This is a framework for validating objects according to policies.
The policies are organized in layers of rings and ring sections,
each policy has a serial number and a description of its purpose.
When an object is validated, a report is generated containing all
validated policys and the result of failed policys.

# Layers:

The layers of policys is divided into 7 rings where 1 is the
innermost layer. Each layer can be divided into sections.
Each individual policy has a totally unique serial number that is
chronological from when the policys where organized, and a description.

Example: 1A-0001; Policy purpose and description.

* 1: Fields
  * A: ...
  * B: ...
* 2: Documents
  * C: ...
  * D: ...
  * E: ...
* 3: Portfolios
  * F: ...
  * G: ...
  * H: ...
  * J: ...
* 4: Facade
  * K: ...
  * L: ...
  * M: ...
  * N: ...
* 5: Nodes
  * P: ...
  * Q: ...
  * R: ...
  * S: ...
* 6: Domain
  * T: ...
  * U: ...
  * V: ...
  * X: ...
* 7: Network
  * Y: ...
  * Z: ...

"""
import datetime
import logging
import uuid
from abc import ABC, abstractmethod
from contextlib import ContextDecorator, AbstractContextManager
# Removed becuase of backward comaptability with 3.6
# AbstractAsyncContextManager
from contextvars import ContextVar

from angelos.lib.error import AngelosException
from angelos.common.utils import Util

report_ctx = ContextVar("report", default=None)


class Report:
    """Validation report that keeps a record of applied policies and failures."""

    NULL_POLICY = (uuid.UUID(int=0).bytes, ord(b'I'), 0)  # Null policy
    NULL_IDENTITY = uuid.UUID(int=0)
    POLICY = {b'A': "1A", b'B': "1B", b'C': "2C", b'D': "2D", b'E': "2E", b'F': "3F",
              b'G': "3G", b'H': "3H", b'J': "3J", b'K': "4K", b'L': "4L", b'M': "4M",
              b'N': "4N", b'P': "5P", b'Q': "5Q", b'R': "5R", b'S': "5S", b'T': "6T",
              b'U': "6U", b'V': "6V", b'X': "6X", b'Y': "7Y", b'Z': "7Z"}

    def __init__(self, event=None):
        self.__uuid = uuid.uuid4()
        self.__timestamp = datetime.datetime.now()
        self.__event = event
        self.__applied = list()
        self.__failed = list()

    @property
    def id(self):
        """Report unique UUID"""
        return self.__uuid

    @property
    def timestamp(self):
        """Report timestamp."""
        return self.__timestamp

    @property
    def applied(self):
        """All applied policies."""
        return self.__applied

    @property
    def failed(self):
        """All failed policy runtime ID:s."""
        return self.__failed

    def up(self, level: bytes):
        """Go one level deeper.

        Args:
            level (bytes):
                Level name/info.

        """
        entry = (True, level, True)
        self.__applied.append(entry)

    def down(self, level: bytes):
        """Go back from level depth.

        Args:
            level (bytes):
                Level name/info.

        """
        entry = (True, level, False)
        self.__applied.append(entry)

    def record(self, section: bytes, sn: int, failed: bool = False):
        """Add a policy record.

        Args:
            section (bytes):
                Policy section from which layer is calculated.
            sn (int):
                Policy chronological serial number.
            failed (bool):
                True or False whether the check failed.

        """
        entry = (False, ord(section), sn)
        self.__applied.append(entry)
        if failed:
            self.__failed.append(id(entry))

    def format(self, barrier="-"):
        """Print report."""
        return "{0}\n{1}{2}".format(
            Util.headline("POLICY REPORT", "(Begin)", barrier),
            self,
            Util.headline("POLICY REPORT", "(End)", barrier)
        )

    def __str__(self):
        """Written report of all applied policies and failures."""
        output = "Report: {0}\nTimestamp: {1}\nEvent: {2}\n{3}\n".format(
            self.__uuid,
            self.__timestamp,
            self.__event,
            Util.headline("Report Body", barrier="-")
        )
        up = ">>>"
        down = "<<<"

        for p in self.__applied:
            if p[0]:
                output += "{0} ({1:s}) {0}\n".format((up if p[2] else down), p[1].decode())
            else:
                output += "{0}-{1:0>4}  {2}\n".format(
                    Report.POLICY[chr(p[1])] if p[1] in Report.POLICY else "0I",
                    p[2],
                    "Failure" if id(p) in self.__failed else "Success"
                )

        return output

    def __bool__(self):
        """State of the report.

        If report has applied policies without failure it's True, but False if empty or with failures.
        """
        return bool(self.__applied) and not bool(self.__failed)


class PolicyException(AngelosException):
    pass


class PolicyBreachException(AngelosException):
    def __init__(self, message, report: Report):
        super().__init__(message)
        self.report = report

    def __str__(self):
        return self.report.format("=")


def policy(section, sn, level=None):  # TODO: Write unittest
    """Policy decorator.

    Args:
        section (bytes):
            Policy section
        sn (int):
            Policy serial number
        level (str):
            Instruct report to add a level

    Returns (callable):
        Wrapper writing policy to the report

    """
    def decorator(func):
        """Decorating the function.

        Args:
            func (callable):
                The function being decorated

        Returns:

        """
        def wrapper(self, *args, **kwargs):
            """Wrapping the callable.

            Args:
                self (class):
                    Method owner
                *args:
                    Any arguments
                **kwargs:
                    Any keyword arguments

            Returns:
                The result from the callable

            """
            report = report_ctx.get()
            if level:
                level_str = str(level).encode()
            if isinstance(report, Report):
                result = None
                if level: report.up(level_str)
                try:
                    result = func(self, *args, **kwargs)
                    failure = False
                except PolicyException as e:
                    failure = True
                report.record(section, sn, failure)
                if level: report.down(level_str)
                return result
            else:
                return func(self, *args, **kwargs)

        return wrapper

    return decorator


# Should be if not for 3.6 backward compatibility.
# AbstractAsyncContextManager
class evaluate(ContextDecorator, AbstractContextManager):
    """Evaluate decorator and context manager.

    Wrap methods or enclose pieces of code that you want to evaluate
    that they are complying with certain policies.
    """

    def __init__(self, event = None):
        self.__token = report_ctx.set(Report(event))

    def __enter__(self):
        return report_ctx.get()

    async def __aenter__(self):
        return report_ctx.get()

    def __evaluate(self):
        report = report_ctx.get()
        report_ctx.reset(self.__token)
        if not report:
            logging.error("Policy breach found, REPORT: {0}, TIMESTAMP; {1}".format(report.id, report.timestamp))
            raise PolicyBreachException("Policy breach found", report)

    def __exit__(self, exc_type, exc_value, traceback):
        if exc_type is not None:
            raise exc_type(exc_value)

        self.__evaluate()
        return None

    async def __aexit__(self, exc_type, exc_value, traceback):
        if exc_type is not None:
            raise exc_type(exc_value)

        self.__evaluate()
        return None


class PolicyMixin(ABC):
    """Base class that applies one policy."""

    @abstractmethod
    def apply(self) -> bool:
        """Implement policy to be applied here, then decorate with @policy(section=b'I' sn=0)."""
        pass


class BasePolicyApplier(ABC):
    """Apply all mixed in policies."""

    def _applier(self) -> bool:
        self._setup()
        success = all([cls.apply(self) for cls in self.__class__.mro()[3:-3] if hasattr(cls, "apply")])
        self._clean()
        return success

    @abstractmethod
    def _setup(self):
        """Carry out setup operation before applying."""
        pass

    @abstractmethod
    def _clean(self):
        """Carry out clean up operation after applying."""
        pass


class PolicyValidator(BasePolicyApplier):
    """Base class for policies that validates data."""

    @abstractmethod
    def validate(self, **kwargs):
        """Execute validation."""
        pass


class PolicyPerformer(BasePolicyApplier):
    """Base class for policies to be performed."""

    @abstractmethod
    def perform(self, **kwargs):
        """Perform an action."""
        pass


#### OLD IMPLEMENTATION THAT IS GOING AWAY ====

rep_ctx = ContextVar("rep", default=None)


class Rep:
    """Validation report that keeps a record of applied policies and failures."""

    NULL_POLICY = (uuid.UUID(int=0).bytes, ord(b'I'), 0)  # Null policy
    NULL_IDENTITY = uuid.UUID(int=0)
    POLICY = {b'A': "1A", b'B': "1B", b'C': "2C", b'D': "2D", b'E': "2E", b'F': "3F",
              b'G': "3G", b'H': "3H", b'J': "3J", b'K': "4K", b'L': "4L", b'M': "4M",
              b'N': "4N", b'P': "5P", b'Q': "5Q", b'R': "5R", b'S': "5S", b'T': "6T",
              b'U': "6U", b'V': "6V", b'X': "6X", b'Y': "7Y", b'Z': "7Z"}

    def __init__(self, validator: "BaseValidator"):
        self.__validator = str(validator)
        self.__applied = set()
        self.__failed = set()

    @property
    def applied(self):
        """All applied policies."""
        return self.__applied

    @property
    def failed(self):
        """All failed policies."""
        return self.__failed

    def record(self, identity: uuid.UUID, section: bytes, sn: int, failed: bool = False):
        """Add a policy record.

        Args:
            identity (uuid.UUID):
                The identity of the object having policies checked.
            section (bytes):
                Policy section from which layer is calculated.
            sn (int):
                Policy chronological serial number.
            failed (bool):
                True or False whether the check failed.

        """
        entry = (identity.bytes, ord(section), sn)
        self.__applied.add(entry)
        if failed:
            self.__failed.add(entry)

    def __str__(self):
        """Written report of all applied policies and failures."""
        output = "Report on policies: {0}\n".format(self.__validator)
        for p in self.__applied:
            output += "{1}-{2:0>4}:{0!s}  {3}\n".format(
                uuid.UUID(bytes=p[0]),
                Rep.POLICY[chr(p[1])] if p[1] in Rep.POLICY else "0I",
                p[2],
                "Failure" if p in self.__failed else "Success"
            )
        return output

    def __bool__(self):
        """State of the report.

        If report has applied policies without failure it's True, but False if empty or with failures.
        """
        return bool(self.__applied) and not bool(self.__failed)


class BaseValidatable(ABC):
    """Object that can be validated according to specific policies and return a report."""

    def _checker(
            self, rules: list, report: Rep = None,
            identity: uuid.UUID = Rep.NULL_IDENTITY, attr: str = None
    ) -> bool:
        """Internal checker for validating the self._check_* methods.

        Args:
            rules (list):
                List of tuples containing a check callback and policy.
            report (Report):
                Report object where validation is reported to.
            identity (uuid.UUID):
                Identity of object having policies applied to.
            attr (str):
                Attribute name for class bellow document without specific id.

        Returns (bool):
            Result of the checks, True if all passed or False.

        """
        valid = True
        namespace = uuid.uuid5(identity, attr) if attr else identity

        for rule in rules:
            try:
                rule[0]()
                failure = False
            except Exception as e:
                failure = True
                logging.error(e, exc_info=True)
                valid = False

            if report is not None:
                report.record(namespace, rule[1], rule[2], failure)

        return valid

    @abstractmethod
    def apply_rules(self, report: Rep = None, identity: uuid.UUID = Rep.NULL_IDENTITY) -> bool:
        """Apply all the rules defined within.

        Example:
            rules = [
                (self._check_something, b'I', 345)
            ]
            return self._checker(rules, report, identity)

        Args:
            identity (uuid.UUID):
                Identity to use if this class is a sub validatable.
            report (Report):
                The journal of the validation result.

        Returns (bool):
            Result of the rules, True if all passed or False.
        """
        return True


class BaseValidator(ABC):
    """Validators are classes that is used to validate according to specific policies and stems from this class."""

    def __str__(self):
        return self.__class__.__name__

    def _validator(self, validatable: BaseValidatable, report: Rep) -> bool:
        valid = True
        classes = set(validatable.__class__.mro())

        for cls in classes:
            if issubclass(cls, BaseValidatable):
                valid = valid if cls.apply_rules(validatable, report) else False

        return valid

    def validate(self) -> Rep:
        """Validate its own classes that are validatables.

        Returns (Report):
            Report with applied and failed policies.

        """
        report = Rep(self)
        valid = self._validator(self, report)

        if valid and len(report.failed):
            raise RuntimeError("Inaccurate report of failures and validation success.")

        return report