# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Server data extension.

Exposes a preferences file with reactive properties to the facade.
"""
from libangelos.data.data import DataFacadeExtension
from libangelos.facade.base import BaseFacade

from libangelos.data.dict_mixin import DictionaryMixin


class ServerData(DataFacadeExtension, DictionaryMixin):
    """
    The preferences file data interface.
    """

    ATTRIBUTE = ("server",)
    SECTION = ("Server",)

    def __init__(self, facade: BaseFacade):
        DataFacadeExtension.__init__(self, facade)
        DictionaryMixin.__init__(self)
