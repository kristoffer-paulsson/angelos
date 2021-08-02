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
import sys
from pathlib import PurePath

here = PurePath(__file__)
sys.path.append(here.parents[2].joinpath("test"))

def load_tests(loader, suite, pattern):
    """Test loader for a certain package."""
    tests = loader.discover(start_dir=here.parents[0], pattern=pattern)
    suite.addTests(tests)
    return suite
