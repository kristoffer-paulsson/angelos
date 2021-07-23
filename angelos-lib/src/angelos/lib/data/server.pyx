# cython: language_level=3, linetrace=True
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
"""Server data extension.

Exposes a preferences file with reactive properties to the facade.
"""
from angelos.lib.data.data import DataFacadeExtension
from angelos.lib.facade.base import BaseFacade

from angelos.lib.data.dict_mixin import DictionaryMixin


class ServerData(DataFacadeExtension, DictionaryMixin):
    """
    The preferences file data interface.
    """

    ATTRIBUTE = ("server",)
    SECTION = ("Server",)

    def __init__(self, facade: BaseFacade):
        DataFacadeExtension.__init__(self, facade)
        DictionaryMixin.__init__(self)
