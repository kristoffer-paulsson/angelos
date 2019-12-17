# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Home."""
from libangelos.const import Const
from libangelos.archive.storage import StorageFacadeExtension


class HomeStorage(StorageFacadeExtension):
    """
    Storage for internal user files and folders.
    """
    ATTRIBUTE = ("home",)
    CONCEAL = (Const.CNL_HOME,)
    USEFLAG = (Const.A_USE_HOME,)