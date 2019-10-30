# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import uuid

import plyer


class Helper:
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
