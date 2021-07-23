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
import datetime

from angelos.common.policy import PolicyException
from angelos.document.envelope import Envelope, Header
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio


class EnvelopePolicy:
    def _add_header(self, handler: PrivatePortfolio, envelope: Envelope, operation: str):
        if operation not in ("SEND", "RTE", "RECV"):
            raise PolicyException()

        header = Header(nd={
            "op": operation,
            "issuer": handler.entity.id,
            "timestamp": datetime.datetime.utcnow()
        })

        header = Crypto.sign_header(envelope, header, handler)
        envelope.header.append(header)