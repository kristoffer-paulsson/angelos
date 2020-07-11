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
"""Pool."""
from libangelos.storage.portfolio_mixin import PortfolioMixin
from libangelos.const import Const
from libangelos.storage.storage import StorageFacadeExtension


class PoolStorage(StorageFacadeExtension, PortfolioMixin):
    """
    Storage for the information pool.
    """
    ATTRIBUTE = ("pool",)
    CONCEAL = (Const.CNL_POOL,)
    USEFLAG = (Const.A_USE_POOL,)