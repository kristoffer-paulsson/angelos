# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


SSH start logic."""
import asyncio
import logging

import asyncssh

from .utils import Util
from .ioc import Container
from .document import Keys
from .policy import PrivatePortfolio, Portfolio
from .ssh.nacl import NaClKey, NaClPublicKey, NaClPrivateKey
from .ssh.ssh import SSHClient, SSHServer
from .ssh.console import BootServer, AdminServer
from .ssh.client import ClientsServer, ClientsClient
from .server.rsa import SERVER_RSA_PRIVATE


class Starter:
    """This class contains the methods for starting SSH clients and servers."""

    ALGS = {
        'kex_algs': ('diffie-hellman-group18-sha512', ),
        'encryption_algs': ('chacha20-poly1305@openssh.com', ),
        'mac_algs': ('hmac-sha2-512-etm@openssh.com', ),
        'compression_algs': ('zlib', ),
        'signature_algs': ('angelos-tongues', )
    }

    SARGS = {
        'backlog': 200,
        'x509_trusted_certs': [],
        'x509_purposes': False,
        'gss_host': False,
        'allow_pty': False,
        'x11_forwarding': False,
        'agent_forwarding': False,
        'sftp_factory': False,
        'allow_scp': False,
    }

    @classmethod
    def nodes_server(
            self, portfolio, host, port=3, ioc=None, loop=None):
        """Start server for incoming node/domain communications."""
        Util.is_type(portfolio, PrivatePortfolio)
        Util.is_type(host, str)
        Util.is_type(port, int)
        Util.is_type(ioc, Container)
        Util.is_type(loop, asyncio.base_events.BaseEventLoop)

        params = {
            'server_factory': SSHServer,
            'host': host,
            'port': port,
            'server_host_keys': [Starter._private_key(portfolio.privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
            'loop': loop,
        }
        params = {**params, **self.ALGS, **self.SARGS}

        return Starter.__start_server(params)

    @classmethod
    def nodes_client(self, portfolio, host_keys, host, port=3):
        """Start client for outgoing node/domain communications."""
        Util.is_type(portfolio, PrivatePortfolio)
        Util.is_type(host_keys, Keys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'username': str(portfolio.entity.id),
            'client_username': str(portfolio.entity.id),
            'host': host,
            'port': port,
            'client_keys': [Starter._private_key(portfolio.privkeys)],
            'known_hosts': Starter.__known_host(host_keys),
            'client_factory': SSHClient
        }
        params = {**params, **self.ALGS}

        return Starter.__start_client(params)  # (conn, client)

    @classmethod
    def hosts_server(
            self, portfolio, host, port=4, ioc=None, loop=None):
        """Start server for incoming host/host communications."""
        Util.is_type(portfolio, PrivatePortfolio)
        Util.is_type(host, str)
        Util.is_type(port, int)
        Util.is_type(ioc, Container)
        Util.is_type(loop, asyncio.base_events.BaseEventLoop)

        params = {
            'server_factory': SSHServer,
            'host': host,
            'port': port,
            'server_host_keys': [Starter._private_key(portfolio.privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
            'loop': loop,
        }
        params = {**params, **self.ALGS, **self.SARGS}

        return Starter.__start_server(params)

    @classmethod
    def hosts_client(self, portfolio, host_keys, host, port=4):
        """Start client for outgoing host/host communications."""
        Util.is_type(portfolio, PrivatePortfolio)
        Util.is_type(host_keys, Keys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'username': str(portfolio.entity.id),
            'client_username': str(portfolio.entity.id),
            'host': host,
            'port': port,
            'client_keys': [Starter._private_key(portfolio.privkeys)],
            'known_hosts': Starter.__known_host(host_keys),
            'client_factory': SSHClient
        }
        params = {**params, **self.ALGS}

        return Starter.__start_client(params)  # (conn, client)

    @classmethod
    def clients_server(
            self, portfolio: PrivatePortfolio, host: str, port: int=5,
            ioc: Container=None, loop: asyncio.base_events.BaseEventLoop=None):
        """Start server for incoming client/portal communications."""

        params = {
            'server_factory': lambda: ClientsServer(ioc),
            'host': host,
            'port': port,
            'server_host_keys': [Starter._private_key(portfolio.privkeys)],
            'loop': loop,
        }
        params = {**params, **self.ALGS, **self.SARGS}

        return Starter.__start_server(params)

    def clients_client(
            self, portfolio: PrivatePortfolio, host: Portfolio,
            port: int=5, ioc: Container=None):
        """Start client for outgoing client/portal communications."""
        if host.network.hosts[0].ip:
            location = str(host.network.hosts[0].ip[0])
        else:
            location = str(host.network.hosts[0].hostname[0])

        location = 'localhost'

        params = {
            'username': str(portfolio.entity.id),
            'client_username': str(portfolio.entity.id),
            'host': location,
            'port': port,
            'client_keys': [Starter._private_key(portfolio.privkeys)],
            'known_hosts': Starter.__known_host(host.keys),
            'client_factory': lambda: ClientsClient(ioc)
        }
        params = {**params, **Starter.ALGS}

        return Starter.__start_client(params)  # (conn, client)

    def admin_server(
            self, host, port=22, ioc=None, loop=None):
            # self, entity, privkeys, host, port=22, ioc=None, loop=None):
        """Start shell server for incoming admin communications."""
        """Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host, str)
        Util.is_type(port, int)
        Util.is_type(ioc, Container)
        Util.is_type(loop, asyncio.base_events.BaseEventLoop)

        params = {
            'server_factory': lambda AdminServer(ioc),
            'host': host,
            'port': port,
            'server_host_keys': [Starter._private_key(privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
            'loop': loop,
        }
        params = {**params, **self.ALGS, **self.SARGS}

        return Starter.__start_server(params)"""

        Util.is_type(host, str)
        Util.is_type(port, int)
        Util.is_type(ioc, Container)
        Util.is_type(loop, asyncio.base_events.BaseEventLoop)

        params = {
            'server_factory': lambda: AdminServer(ioc),
            'host': host,
            'port': port,
            'loop': loop,
            'server_host_keys': [
                asyncssh.import_private_key(SERVER_RSA_PRIVATE)],
        }
        params = {**params, **self.SARGS}
        params['allow_pty'] = True

        return Starter.__start_server(params)

    def boot_server(self, host, port=22, ioc=None, loop=None):
        """Start shell server for incoming boot communications."""
        Util.is_type(host, str)
        Util.is_type(port, int)
        Util.is_type(ioc, Container)
        Util.is_type(loop, asyncio.base_events.BaseEventLoop)

        params = {
            'server_factory': lambda: BootServer(ioc),
            'host': host,
            'port': port,
            'loop': loop,
            'server_host_keys': [
                asyncssh.import_private_key(SERVER_RSA_PRIVATE)],
        }
        params = {**params, **self.SARGS}
        params['allow_pty'] = True

        return Starter.__start_server(params)

    @staticmethod
    def __start_server(params):
        try:
            return asyncssh.create_server(**params)
        except (OSError, asyncssh.Error) as exc:
            logging.critical('Error starting server: %s' % str(exc))

    @staticmethod
    def __start_client(params):
        try:
            return asyncssh.create_connection(**params)
        except (OSError, asyncssh.Error) as exc:
            logging.critical('SSH connection failed: %s' % str(exc))

    @staticmethod
    def __known_host(host_keys):
        def callback(h, a, p):
            return (
                [NaClKey(key=NaClPublicKey.construct(
                    key.verify)) for key in host_keys], [], [])
        return callback

    @staticmethod
    def public_key(keys):
        return NaClKey(key=NaClPublicKey.construct(keys.verify))

    @staticmethod
    def _private_key(privkeys):
        return NaClKey(key=NaClPrivateKey.construct(privkeys.seed))
