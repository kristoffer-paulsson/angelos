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
"""Reusable document policies."""
from angelos.common.policy import PolicyException, policy
from angelos.document.utils import Helper as DocumentHelper
from angelos.lib.policy.crypto import Crypto


class DocumentPolicy:
    """Policies for regular documents."""

    def __init__(self):
        self._portfolio = None
        self._document = None

    def _add(self):
        """Add a document to portfolio."""
        self._portfolio.__init__(
            self._portfolio.documents() | {self._document}, frozen=self._portfolio.is_frozen())

    @policy(b'I', 0)
    def _check_document_issuer(self) -> bool:
        if self._document.issuer != self._portfolio.entity.id:
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_document_expired(self) -> bool:
        if self._document.is_expired():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_document_valid(self) -> bool:
        if not self._document.validate():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_document_verify(self) -> bool:
        if not Crypto.verify(self._document, self._portfolio):
            raise PolicyException()
        return True


class IssuePolicy(DocumentPolicy):
    """Policies for issuing documents."""

    def __init__(self):
        DocumentPolicy.__init__(self)
        self._owner = None


class UpdatablePolicy(DocumentPolicy):
    """Policies for updatable and changeable documents."""

    def __init__(self):
        DocumentPolicy.__init__(self)
        self._former = None

    def _update(self):
        """Update document in portfolio. by replacing old."""
        self._portfolio.__init__(
            self._portfolio.filter(self._former) | {self._document}, frozen=self._portfolio.is_frozen())

    @policy(b'I', 0)
    def _check_fields_unchanged(self) -> bool:
        exclude = DocumentHelper.excludes(self._document)
        if DocumentHelper.flatten_document(self._document, exclude) != DocumentHelper.flatten_document(self._former, exclude):
            raise PolicyException()
        return True