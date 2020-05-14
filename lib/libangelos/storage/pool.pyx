# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
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