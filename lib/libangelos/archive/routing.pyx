# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Routing."""
from ..const import Const
from .storage import StorageFacadeExtension


class RoutingStorage(StorageFacadeExtension):
    ATTRIBUTE = ("routing",)
    CONCEAL = (Const.CNL_ROUTING,)
    USEFLAG = (Const.A_USE_ROUTING,)