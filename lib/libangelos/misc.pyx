# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import abc
import uuid
from dataclasses import dataclass, asdict as data_asdict

import plyer


@dataclass
class BaseDataClass(metaclass=abc.ABCMeta):
    """A base dataclass with some basic functions"""

    def _asdict(self) -> dict:
        return data_asdict(self)


class ThresholdCounter:
    """
    ThresholdCounter is a helper class that counts ticks and alarms
    when the threshold is reached.
    """
    def __init__(self, threshold=3):
        """
        Initializes an instanceself.
        threshold	An integer defining the threshold.
        """
        self.__cnt = 0
        self.__thr = threshold

    def tick(self):
        """
        Counts one tick.
        """
        self.__cnt += 1

    def reset(self):
        """
        Resets the counter.
        """
        self.__cnt == 0

    def limit(self):
        """
        Returns True when the threshold is met.
        """
        return self.__cnt >= self.__thr


class Misc:
    """Namespace for miscellanious functions and methods."""
    @staticmethod
    def unique() -> str:
        """Get the hardware ID.

        Tries to find the uniqueid of the hardware, otherwise returns MAC
        address.

        Returns
        -------
        string
            Unique hardware id.

        """
        try:
            serial = plyer.uniqueid.id
            if isinstance(serial, bytes):
                serial = serial.decode()
            return serial
        except NotImplementedError:
            return str(uuid.getnode())
