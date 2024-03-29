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
"""Layout for new Facade framework."""
from angelos.lib.facade.base import BaseFacade, FacadeExtension


class ApiFacadeExtension(FacadeExtension):
    """API extensions that let developers interact with the facade."""

    def __init__(self, facade: BaseFacade):
        """Initialize the Mail."""
        FacadeExtension.__init__(self, facade)