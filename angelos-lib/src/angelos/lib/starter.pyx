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
import logging

import asyncssh
from angelos.document.entities import Keys
from angelos.lib.ioc import Container
from angelos.lib.policy.portfolio import PrivatePortfolio, Portfolio
from angelos.lib.ssh.client import ClientsServer, ClientsClient
from angelos.lib.ssh.nacl import NaClKey, NaClPublicKey, NaClPrivateKey
from angelos.lib.ssh.ssh import SSHClient, SSHServer


class Starter:
    """This class contains the methods for starting SSH clients and servers."""

    ALGS = {
        "kex_algs": ("diffie-hellman-group18-sha512",),
        "encryption_algs": ("chacha20-poly1305@openssh.com",),
        "mac_algs": ("hmac-sha2-512-etm@openssh.com",),
        "compression_algs": ("zlib",),
        "signature_algs": ("angelos-tongues",),
    }

    SARGS = {
        "backlog": 200,
        "x509_trusted_certs": [],
        "x509_purposes": False,
        "gss_host": False,
        "allow_pty": False,
        "x11_forwarding": False,
        "agent_forwarding": False,
        "sftp_factory": False,
        "allow_scp": False,
    }

    @classmethod
    def nodes_server(
        self,
        portfolio: PrivatePortfolio,
        host: str,
        port: int = 3,
        ioc: Container = None,
        loop: asyncio.base_events.BaseEventLoop = None
    ):
        """Start server for incoming node/domain communications."""
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
    def nodes_client(
        self,
        portfolio: PrivatePortfolio,
        host_keys: Keys,
        host: str,
        port: int = 3
    ):
        """Start client for outgoing node/domain communications."""
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

    @classmethod
    def clients_server(
        self,
        portfolio: PrivatePortfolio,
        host: str,
        port: int = 5,
        ioc: Container = None,
        loop: asyncio.base_events.BaseEventLoop = None,
    ):
        """Start server for incoming client/portal communications."""

        params = {
            "server_factory": lambda: ClientsServer(ioc),
            "host": host,
            "port": port,
            "server_host_keys": [Starter.private_key(portfolio.privkeys)],
            # "loop": loop,
        }
        params = {**params, **self.ALGS, **self.SARGS}

        return Starter.start_server(params)

    def clients_client(
        self,
        portfolio: PrivatePortfolio,
        host: Portfolio,
        port: int = 5,
        ioc: Container = None,
    ):
        """Start client for outgoing client/portal communications."""
        if host.network.hosts[0].ip:
            location = str(host.network.hosts[0].ip[0])
        else:
            location = str(host.network.hosts[0].hostname[0])

        params = {
            "username": str(portfolio.entity.id),
            "client_username": str(portfolio.entity.id),
            "host": location,
            "port": port,
            "client_keys": [Starter.private_key(portfolio.privkeys)],
            "known_hosts": Starter.known_host(host.keys),
            "client_factory": lambda: ClientsClient(ioc),
        }
        params = {**params, **Starter.ALGS}

        return Starter.start_client(params)  # (conn, client)

    @staticmethod
    def start_server(params):
        """

        Args:
            params:

        Returns:

        """
        try:
            return asyncssh.create_server(**params)
        except (OSError, asyncssh.Error) as exc:
            logging.critical("Error starting server: %s" % str(exc), exc_info=True)

    @staticmethod
    def start_client(params):
        """

        Args:
            params:

        Returns:

        """
        try:
            conn = asyncssh.create_connection(**params)
            return conn
        except (OSError, asyncssh.Error) as exc:
            logging.critical("SSH connection failed: %s" % str(exc), exc_info=True)

    @staticmethod
    def known_host(host_keys):
        """

        Args:
            host_keys:

        Returns:

        """
        def callback(h, a, p):
            return (
                [
                    NaClKey(key=NaClPublicKey.construct(key.verify))
                    for key in host_keys
                ],
                [],
                [],
            )

        return callback

    @staticmethod
    def public_key(keys):
        """
        Prepares a public key for SSH use

        Args:
            keys:

        Returns:

        """
        return NaClKey(key=NaClPublicKey.construct(keys.verify))

    @staticmethod
    def private_key(privkeys):
        """
        Prepares a private key for SSH use

        Args:
            privkeys:

        Returns:

        """
        return NaClKey(key=NaClPrivateKey.construct(privkeys.seed))
