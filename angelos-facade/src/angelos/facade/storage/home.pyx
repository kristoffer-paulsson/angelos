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
"""Home."""
from angelos.facade.facade import StorageFacadeExtension
from angelos.lib.const import Const


class HomeStorage(StorageFacadeExtension):
    """
    Storage for internal user files and folders.
    """
    ATTRIBUTE = ("home",)
    CONCEAL = (Const.CNL_HOME,)
    USEFLAG = (Const.A_USE_HOME,)