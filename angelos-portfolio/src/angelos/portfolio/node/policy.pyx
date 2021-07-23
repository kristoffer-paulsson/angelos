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
from angelos.common.policy import PolicyException, policy


class NodePolicy:

    @policy(b"I", 0)
    def _check_domain_issuer(self) -> bool:
        """The domain must have same issuer as issuing entity."""
        if self._portfolio.domain.issuer != self._portfolio.entity.issuer:
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_node_domain(self) -> bool:
        if self._document.domain != self._portfolio.domain.id:
            raise PolicyException()
        return True