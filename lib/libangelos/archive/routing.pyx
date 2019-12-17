# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Routing."""
from libangelos.const import Const
from libangelos.archive.storage import StorageFacadeExtension


class RoutingStorage(StorageFacadeExtension):
    """
    Storage for inter-domain mail routing.
    """
    ATTRIBUTE = ("routing",)
    CONCEAL = (Const.CNL_ROUTING,)
    USEFLAG = (Const.A_USE_ROUTING,)