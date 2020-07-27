# cython: language_level=3
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
from angelos.lib.data.data import DataFacadeExtension
from angelos.document.domain import Node
from angelos.lib.facade.base import BaseFacade
from angelos.lib.policy.portfolio import PrivatePortfolio


class PortfolioData(DataFacadeExtension, PrivatePortfolio):
    """
    The private portfolio of the owner is accessible from here.
    """

    ATTRIBUTE = ("portfolio",)

    def __init__(self, facade: BaseFacade):
        DataFacadeExtension.__init__(self, facade)
        PrivatePortfolio.__init__(self)

    @property
    def node(self) -> Node:
        """Current node representing the running device."""
        nid = self.facade.storage.vault.archive.stats().node
        return list(filter(lambda doc: doc.id == nid, self.nodes))[0]
