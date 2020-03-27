# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
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
import logging
import uuid
from abc import ABC, abstractmethod


class Report:
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
                Report.POLICY[chr(p[1])] if p[1] in Report.POLICY else "0I",
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
            self, rules: list, report: Report = None,
            identity: uuid.UUID = Report.NULL_IDENTITY, attr: str = None
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
    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY) -> bool:
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

    def _validator(self, validatable: BaseValidatable, report: Report) -> bool:
        valid = True
        classes = set(validatable.__class__.mro())

        for cls in classes:
            if issubclass(cls, BaseValidatable):
                valid = valid if cls.apply_rules(validatable, report) else False

        return valid

    def validate(self) -> Report:
        """Validate its own classes that are validatables.

        Returns (Report):
            Report with applied and failed policies.

        """
        report = Report(self)
        valid = self._validator(self, report)

        if valid and len(report.failed):
            raise RuntimeError("Inaccurate report of failures and validation success.")

        return report