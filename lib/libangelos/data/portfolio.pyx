# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Portfolio data extension.

Exposes the facades owning portfolio for use within the facade and its extensions at runtime.
"""
from libangelos.data.data import DataFacadeExtension
from libangelos.document.domain import Node
from libangelos.facade.base import BaseFacade
from libangelos.policy.portfolio import PrivatePortfolio


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
