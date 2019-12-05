# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Pool."""
from ..const import Const
from .storage import StorageFacadeExtension


class PoolStorage(StorageFacadeExtension):
    ATTRIBUTE = ("pool",)
    CONCEAL = (Const.CNL_POOL,)
    USEFLAG = (Const.A_USE_POOL,)