# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""SSH start logic.

@todo Add return types to Starter functions
"""
import asyncio

import asyncssh

from libangelos.starter import Starter
from libangelos.ioc import Container
from libangelos.document.entities import Keys
from libangelos.policy.portfolio import PrivatePortfolio
from libangelos.ssh.ssh import SSHClient, SSHServer
from angelos.console import BootServer, AdminServer
from angelos.vars import SERVER_RSA_PRIVATE


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

        return Starter.start_client(params)  # (conn, client)

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
            # "loop": loop,
            "server_host_keys": [
                asyncssh.import_private_key(SERVER_RSA_PRIVATE)
            ],
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
            # "loop": loop,
            "server_host_keys": [
                asyncssh.import_private_key(SERVER_RSA_PRIVATE)
            ],
        }
        params = {**params, **self.SARGS}
        params["allow_pty"] = True

        return Starter.start_server(params)
