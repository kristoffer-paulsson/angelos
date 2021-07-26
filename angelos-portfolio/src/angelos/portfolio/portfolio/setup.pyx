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
"""Creating new entity portfolio for Person, Ministry and Church including Keys and PrivateKeys documents."""
from ipaddress import IPv4Address, IPv6Address
from typing import Union

from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.lib.const import Const
from angelos.lib.policy.types import PersonData, MinistryData, ChurchData
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.domain.create import CreateDomain
from angelos.portfolio.node.create import CreateNode
from angelos.portfolio.network.create import CreateNetwork
from angelos.portfolio.entity.create import CreatePersonEntity, CreateMinistryEntity, CreateChurchEntity


class SetupEntityMixin(PolicyPerformer, PolicyMixin):
    """Logic fo generating Entity, Keys and PrivateKeys for a new PrivatePortfolio."""

    def __init__(self):
        super().__init__()
        self._klass = None
        self._portfolio = None
        self._data = None
        self._ip = None
        self._hostname = None
        self._role = None
        self._server = None

    def _clean(self):
        self._data = None
        self._ip = None
        self._hostname = None
        self._role = None
        self._server = None

    def apply(self) -> bool:
        """Perform logic to create a new entity with its new portfolio."""
        self._portfolio = self._klass().perform(self._data)
        result = bool(self._portfolio)

        if not all([
            result,
            CreateDomain().perform(self._portfolio),
            CreateNode().current(self._portfolio, self._ip, self._hostname, self._role, self._server),
            CreateNetwork().perform(self._portfolio) if self._server else True
        ]):
            raise PolicyException()

        self._portfolio.freeze()
        return True


class SetupPersonPortfolio(SetupEntityMixin):
    """Generate new person portfolio from data."""

    def _setup(self):
        self._klass = CreatePersonEntity

    @policy(b'I', 0, "Person:Setup")
    def perform(self, data: PersonData, ip: Union[IPv4Address, IPv6Address] = None,
            hostname: str = None, role: int=Const.A_ROLE_PRIMARY, server: bool = False) -> PrivatePortfolio:
        """Perform building of person portfolio."""
        self._data = data
        self._ip = ip
        self._hostname = hostname
        self._role = role
        self._server = server
        self._applier()
        return self._portfolio


class SetupMinistryPortfolio(SetupEntityMixin):
    """Generate new ministry portfolio from data."""

    def _setup(self):
        self._klass = CreateMinistryEntity

    @policy(b'I', 0, "Ministry:Setup")
    def perform(self, data: MinistryData, ip: Union[IPv4Address, IPv6Address] = None,
            hostname: str = None, role: int=Const.A_ROLE_PRIMARY, server: bool = False) -> PrivatePortfolio:
        """Perform building of person portfolio."""
        self._data = data
        self._ip = ip
        self._hostname = hostname
        self._role = role
        self._server = server
        self._applier()
        return self._portfolio


class SetupChurchPortfolio(SetupEntityMixin):
    """Generate new church portfolio from data."""

    def _setup(self):
        self._klass = CreateChurchEntity

    @policy(b'I', 0, "Church:Setup")
    def perform(self, data: ChurchData, ip: Union[IPv4Address, IPv6Address] = None,
            hostname: str = None, role: int=Const.A_ROLE_PRIMARY, server: bool = False) -> PrivatePortfolio:
        """Perform building of person portfolio."""
        self._data = data
        self._ip = ip
        self._hostname = hostname
        self._role = role
        self._server = server
        self._applier()
        return self._portfolio