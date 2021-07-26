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
from angelos.lib.facade.base import FacadeExtension, BaseFacade


class DataFacadeExtension(FacadeExtension):
    """Archive extension to isolate the archives."""

    def __init__(self, facade: BaseFacade):
        FacadeExtension.__init__(self, facade)