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
"""SSH start logic.

@todo Add return types to Starter functions
"""
import asyncio

from angelos.document.entities import Keys
from angelos.lib.ioc import Container
from angelos.lib.policy.portfolio import PrivatePortfolio
from angelos.lib.ssh.ssh import SSHClient, SSHServer

from angelos.server.console import BootServer, AdminServer
from angelos.lib.starter import Starter


class ConsoleStarter(Starter):
    """Server specific services only."""
    @classmethod
    def hosts_server(
        self,
        portfolio: PrivatePortfolio,
        host: str,
        port: int = 4,
        ioc: Container = None,
        loop: asyncio.base_events.BaseEventLoop = None
    ):
        """Start server for incoming host/host communications."""
        params = {
            "server_factory": SSHServer,
            "host": host,
            "port": port,
            "server_host_keys": [Starter.private_key(portfolio.privkeys)],
            "process_factory": lambda: None,
            "session_factory": lambda: None,
            # "loop": loop,
        }
        params = {**params, **self.ALGS, **self.SARGS}

        return Starter.start_server(params)

    @classmethod
    def hosts_client(
        self,
        portfolio: PrivatePortfolio,
        host_keys: Keys,
        host: str,
        port: int = 4
    ):
        """Start client for outgoing host/host communications."""
        params = {
            "username": str(portfolio.entity.id),
            "client_username": str(portfolio.entity.id),
            "host": host,
            "port": port,
            "client_keys": [Starter.private_key(portfolio.privkeys)],
            "known_hosts": Starter.known_host(host_keys),
            "client_factory": SSHClient,
        }
        params = {**params, **self.ALGS}

        return Starter.start_client(params)

    def admin_server(
        self,
        host: str,
        port: int = 22,
        ioc: Container = None,
        loop: asyncio.base_events.BaseEventLoop = None
    ):
        """Start shell server for incoming admin communications."""
        params = {
            "server_factory": lambda: AdminServer(ioc),
            "host": host,
            "port": port,
            "server_host_keys": [ioc.keys.server()],
        }
        params = {**params, **self.SARGS}
        params["allow_pty"] = True

        return Starter.start_server(params)

    def boot_server(
        self,
        host: str,
        port: int = 22,
        ioc: Container = None,
        loop: asyncio.base_events.BaseEventLoop = None
    ):
        """Start shell server for incoming boot communications."""
        params = {
            "server_factory": lambda: BootServer(ioc),
            "host": host,
            "port": port,
            "server_host_keys": [ioc.keys.server()],
        }
        params = {**params, **self.SARGS}
        params["allow_pty"] = True

        return Starter.start_server(params)
