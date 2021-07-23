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
"""Portfolio data extension.

Exposes the facades owning portfolio for use within the facade and its extensions at runtime.
"""
from typing import Set

from angelos.document.document import Document
from angelos.facade.facade import DataFacadeExtension, Facade
from angelos.document.domain import Node
from angelos.portfolio.collection import PrivatePortfolio


class PortfolioData(DataFacadeExtension, PrivatePortfolio):
    """
    The private portfolio of the owner is accessible from here.
    """

    ATTRIBUTE = ("portfolio",)

    def __init__(self, docs: Set[Document], frozen: bool = True):
        DataFacadeExtension.__init__(self, getattr(self, "facade", None))
        PrivatePortfolio.__init__(self, docs, frozen)

    @property
    def node(self) -> Node:
        """Current node representing the running device."""
        return self.get_id(self.facade.storage.vault.archive.stats().node)
