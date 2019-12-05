# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Home."""
from ..const import Const
from .storage import StorageFacadeExtension


class HomeStorage(StorageFacadeExtension):
    ATTRIBUTE = ("home",)
    CONCEAL = (Const.CNL_HOME,)
    USEFLAG = (Const.A_USE_HOME,)