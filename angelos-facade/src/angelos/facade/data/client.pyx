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
"""Preferences data extension.

Exposes a preferences file with reactive properties to the facade.
"""
from angelos.facade.facade import DataFacadeExtension, Facade
from angelos.facade.data.dict_mixin import DictionaryMixin


class ClientData(DataFacadeExtension, DictionaryMixin):
    """
    The preferences file data interface.
    """

    ATTRIBUTE = ("client",)
    SECTION = ("Client",)

    def __init__(self, facade: Facade):
        DataFacadeExtension.__init__(self, facade)
        DictionaryMixin.__init__(self)
