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
"""Baseclasses for policies."""
from abc import ABC

from angelos.lib.validation import BaseValidator, BaseValidatable


class Policy:
    """Abstract baseclass for all policies."""
    pass


#### OLD IMPLEMENTATION ####


class BasePolicy(BaseValidator):
    """Abstract base class for composite policies.
    Each implementation of a policy should be specific for one singular use in the server or app.
    Standardized checks should be inherited through mixins.
    """
    pass


class BasePolicyMixin(BaseValidatable, ABC):
    """Abstract base class for composite policy components.
    The purpose for the policy mixin classes it to implement validation and applying rule checking.
    By implementing mixins, policy checks can be reused over several policy operations.
    """
    pass


