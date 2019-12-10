# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Layout for new Facade framework."""
from libangelos.facade.base import BaseFacade, FacadeExtension


class ApiFacadeExtension(FacadeExtension):
    """API extensions that let developers interact with the facade."""

    def __init__(self, facade: BaseFacade):
        """Initialize the Mail."""
        FacadeExtension.__init__(self, facade)