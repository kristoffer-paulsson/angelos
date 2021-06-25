# cython: language_level=3
#
# Copyright (c) 2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""Find device unique identifier.

http://fit-pc.com/wiki/index.php?title=How_to_retrieve_product_information_from_within_Windows_/_Linux&mobileaction=toggle_view_desktop
"""
import sys
from abc import ABC, abstractmethod


class UniqieIDError(RuntimeError):
    """Failed to identify device."""


class BaseIdentifier(ABC):
    """Unique ID finder base class"""

    SYSTEM = "Unknown"

    @classmethod
    @abstractmethod
    def _unique(cls) -> str:
        pass

    @classmethod
    def get(cls) -> str:
        return cls._unique()


if sys.platform.startswith("darwin"):

    class UniqueIdentifier(BaseIdentifier):
        """Unique ID identifier in Darwin/macOS."""

        @classmethod
        def _unique(cls) -> str:
            raise NotImplementedError("Not implemented on Darwin.")


elif sys.platform.startswith("win32"):

    class UniqueIdentifier(BaseIdentifier):
        """Unique ID identifier in Windows."""

        @classmethod
        def _unique(cls) -> str:
            raise NotImplementedError("Not implemented on Windows.")


else:

    from subprocess import PIPE, Popen


    class UniqueIdentifier(BaseIdentifier):
        """Unique ID identifier in Unix/Linux."""

        @classmethod
        def _unique(cls) -> str:
            with Popen("cat /sys/class/dmi/id/product_serial", shell=True, stdout=PIPE) as proc:
                if proc.returncode:
                    raise UniqieIDError("Process failure finding unique ID: {}".format(proc.returncode))
                unique = proc.stdout.read()
                if not unique:
                    raise UniqieIDError("Unique ID couldn't be found")
                return unique
