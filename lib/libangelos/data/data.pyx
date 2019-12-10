# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Layout for new Facade framework."""
from libangelos.facade.base import FacadeExtension, BaseFacade


class DataFacadeExtension(FacadeExtension):
    """Archive extension to isolate the archives."""

    def __init__(self, facade: BaseFacade):
        FacadeExtension.__init__(self, facade)