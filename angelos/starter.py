import asyncio
import logging

import asyncssh

from .utils import Util
from .document.entities import Entity, PrivateKeys, Keys
from .ssh.nacl import NaClKey, NaClPublicKey, NaClPrivateKey
from .ssh.ssh import SSHClient, SSHServer


class Starter:
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
    def node_server(cls, entity, privkeys, host, port=22):
        """Starts a server for incoming node/domain communications"""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'server_factory': SSHServer,
            'host': host,
            'port': port,
            'server_host_keys': [cls._private_key(privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
        }
        params = {**params, **cls.ALGS, **cls.SARGS}

        return cls.__start_server(params)

    @classmethod
    def node_client(cls, entity, privkeys, host_keys, host, port=22):
        """Starts a client for outgoing node/domain communications"""
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
            'client_keys': [cls._private_key(privkeys)],
            'known_hosts': cls.__known_host(host_keys),
            'client_factory': SSHClient
        }
        params = {**params, **cls.ALGS}

        return cls.__start_client(params)  # (conn, client)

    @classmethod
    def host_server(cls, entity, privkeys, host, port=22):
        """Starts a server for incoming host/host communications"""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'server_factory': SSHServer,
            'host': host,
            'port': port,
            'server_host_keys': [cls._private_key(privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
        }
        params = {**params, **cls.ALGS, **cls.SARGS}

        return cls.__start_server(params)

    @classmethod
    def host_client(cls, entity, privkeys, host_keys, host, port=22):
        """Starts a client for outgoing host/host communications"""
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
            'client_keys': [cls._private_key(privkeys)],
            'known_hosts': cls.__known_host(host_keys),
            'client_factory': SSHClient
        }
        params = {**params, **cls.ALGS}

        return cls.__start_client(params)  # (conn, client)

    @classmethod
    def portal_server(cls, entity, privkeys, host, port=22):
        """Starts a server for incoming client/portal communications"""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'server_factory': SSHServer,
            'host': host,
            'port': port,
            'server_host_keys': [cls._private_key(privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
        }
        params = {**params, **cls.ALGS, **cls.SARGS}

        return cls.__start_server(params)

    @classmethod
    def portal_client(cls, entity, privkeys, host_keys, host, port=22):
        """Starts a client for outgoing client/portal communications"""
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
            'client_keys': [cls._private_key(privkeys)],
            'known_hosts': cls.__known_host(host_keys),
            'client_factory': SSHClient
        }
        params = {**params, **cls.ALGS}

        return cls.__start_client(params)  # (conn, client)

    @classmethod
    def shell_server(cls, entity, privkeys, host, port=22):
        """Starts a shell server for incoming admin communications"""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'server_factory': SSHServer,
            'host': host,
            'port': port,
            'server_host_keys': [cls._private_key(privkeys)],
            'process_factory': lambda: None,
            'session_factory': lambda: None,
        }
        params = {**params, **cls.ALGS, **cls.SARGS}

        return cls.__start_server(params)

    @classmethod
    def boot_server(cls, host, port=22):
        """Starts a shell server for incoming boot communications"""
        pass

    @classmethod
    def __start_server(cls, params):
        try:
            return asyncio.get_event_loop().run_until_complete(
                asyncssh.create_server(**params))
        except (OSError, asyncssh.Error) as exc:
            logging.critical('Error starting server: %s' % str(exc))

    @classmethod
    def __start_client(cls, params):
        try:
            return asyncio.get_event_loop().run_until_complete(
                asyncssh.create_connection(**params))
        except (OSError, asyncssh.Error) as exc:
            logging.critical('SSH connection failed: %s' % str(exc))

    @classmethod
    def __known_host(cls, host_keys):
        def callback(h, a, p):
            return (
                [NaClKey(key=NaClPublicKey.construct(
                    host_keys.verify))], [], [])
        return callback

    @classmethod
    def _public_key(cls, keys):
        return NaClKey(key=NaClPublicKey.construct(keys.verify))

    @classmethod
    def _private_key(cls, privkeys):
        return NaClKey(key=NaClPrivateKey.construct(privkeys.seed))
