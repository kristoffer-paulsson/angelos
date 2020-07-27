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
import logging
import sys
import tracemalloc
from unittest import TestCase

import asyncssh

from angelos.meta.testing import run_async


class BaseTestNetwork(TestCase):
    """Base test for facade based unit testing."""

    pref_loglevel = logging.ERROR

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=cls.pref_loglevel)
        asyncssh.logging.set_log_level(cls.pref_loglevel)

    @run_async
    async def setUp(self) -> None:
        pass

    def tearDown(self) -> None:
        pass