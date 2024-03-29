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
"""Project wide test utilities."""
import asyncio
import functools


def run_async(coro):
    """Decorator for asynchronous test cases."""

    @functools.wraps(coro)
    def wrapper(*args, **kwargs):
        """Execute the coroutine with asyncio.run()"""
        return asyncio.run(coro(*args, **kwargs))

    return wrapper