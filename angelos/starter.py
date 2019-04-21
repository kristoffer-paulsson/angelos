"""SSH start logic."""
import asyncio
import logging

import asyncssh

from .utils import Util
from .document.entities import Entity, PrivateKeys, Keys
from .ssh.nacl import NaClKey, NaClPublicKey, NaClPrivateKey
from .ssh.ssh import SSHClient, SSHServer
from .ssh.boot import BootServer
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
    def node_server(self, entity, privkeys, host, port=22):
        """Start server for incoming node/domain communications."""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'server_factory': SSHServer,
            'host': host,
            'port': port,
            'server_host_keys': [Starter._private_key(privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
        }
        params = {**params, **self.ALGS, **self.SARGS}

        return Starter.__start_server(params)

    @classmethod
    def node_client(self, entity, privkeys, host_keys, host, port=22):
        """Start client for outgoing node/domain communications."""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host_keys, Keys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'username': str(entity.id),
            'client_username': str(entity.id),
            'host': host,
            'port': port,
            'client_keys': [Starter._private_key(privkeys)],
            'known_hosts': Starter.__known_host(host_keys),
            'client_factory': SSHClient
        }
        params = {**params, **self.ALGS}

        return Starter.__start_client(params)  # (conn, client)

    @classmethod
    def host_server(self, entity, privkeys, host, port=22):
        """Start server for incoming host/host communications."""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'server_factory': SSHServer,
            'host': host,
            'port': port,
            'server_host_keys': [Starter._private_key(privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
        }
        params = {**params, **self.ALGS, **self.SARGS}

        return Starter.__start_server(params)

    @classmethod
    def host_client(self, entity, privkeys, host_keys, host, port=22):
        """Start client for outgoing host/host communications."""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host_keys, Keys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'username': str(entity.id),
            'client_username': str(entity.id),
            'host': host,
            'port': port,
            'client_keys': [Starter._private_key(privkeys)],
            'known_hosts': Starter.__known_host(host_keys),
            'client_factory': SSHClient
        }
        params = {**params, **self.ALGS}

        return Starter.__start_client(params)  # (conn, client)

    @classmethod
    def portal_server(self, entity, privkeys, host, port=22):
        """Start server for incoming client/portal communications."""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'server_factory': SSHServer,
            'host': host,
            'port': port,
            'server_host_keys': [Starter._private_key(privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
        }
        params = {**params, **self.ALGS, **self.SARGS}

        return Starter.__start_server(params)

    def portal_client(self, entity, privkeys, host_keys, host, port=22):
        """Start client for outgoing client/portal communications."""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host_keys, Keys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'username': str(entity.id),
            'client_username': str(entity.id),
            'host': host,
            'port': port,
            'client_keys': [Starter._private_key(privkeys)],
            'known_hosts': Starter.__known_host(host_keys),
            'client_factory': SSHClient
        }
        params = {**params, **Starter.ALGS}

        return Starter.__start_client(params)  # (conn, client)

    def shell_server(self, entity, privkeys, host, port=22):
        """Start shell server for incoming admin communications."""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'server_factory': SSHServer,
            'host': host,
            'port': port,
            'server_host_keys': [Starter._private_key(privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
        }
        params = {**params, **self.ALGS, **self.SARGS}

        return Starter.__start_server(params)

    def boot_server(self, host, port=22, ioc=None):
        """Start shell server for incoming boot communications."""
        params = {
            'server_factory': lambda: BootServer(ioc),
            'host': host,
            'port': port,
            'server_host_keys': [
                asyncssh.import_private_key(SERVER_RSA_PRIVATE)],
        }
        params = {**params, **self.SARGS}
        params['allow_pty'] = True

        return Starter.__start_server(params)

    @staticmethod
    def __start_server(params):
        try:
            return asyncio.get_event_loop().run_until_complete(
                asyncssh.create_server(**params))
        except (OSError, asyncssh.Error) as exc:
            logging.critical('Error starting server: %s' % str(exc))

    @staticmethod
    def __start_client(params):
        try:
            return asyncio.get_event_loop().run_until_complete(
                asyncssh.create_connection(**params))
        except (OSError, asyncssh.Error) as exc:
            logging.critical('SSH connection failed: %s' % str(exc))

    @staticmethod
    def __known_host(host_keys):
        def callback(h, a, p):
            return (
                [NaClKey(key=NaClPublicKey.construct(
                    host_keys.verify))], [], [])
        return callback

    @staticmethod
    def _public_key(keys):
        return NaClKey(key=NaClPublicKey.construct(keys.verify))

    @staticmethod
    def _private_key(privkeys):
        return NaClKey(key=NaClPrivateKey.construct(privkeys.seed))
