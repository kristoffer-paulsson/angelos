import base64
import asyncio
import logging

import asyncssh

from utils import Util
from document.entities import Entity, PrivateKeys, Keys
from ssh.nacl import NaClKey, NaClPublicKey, NaClPrivateKey
from ssh.ssh import SSHClient, SSHServer


class Starter:
    ALGS = {
        'kex_algs': tuple('diffie-hellman-group18-sha512'),
        'encryption_algs': tuple('chacha20-poly1305@openssh.com'),
        'mac_algs': tuple('hmac-sha2-512-etm@openssh.com'),
        'compression_algs': tuple('zlib'),
        'signature_algs': tuple('angelos-tongues')
    }

    SARGS = {
        'backlog': 200,
        'x509_trusted_certs': False,
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
        } + cls.ALGS + cls.SARGS

        cls.__start_server(params)

    @classmethod
    def node_client(cls, entity, privkeys, host_keys, host, port=22):
        """Starts a client for outgoing node/domain communications"""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host_keys, Keys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'username': entity.id,
            'client_username': entity.id,
            'host': host,
            'port': port,
            'client_keys': [cls._private_key(privkeys)],
            'known_hosts': cls.__known_host(host_keys),
            'client_factory': SSHClient
        } + cls.ALGS

        cls.__start_client(params)

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
        } + cls.ALGS + cls.SARGS

        cls.__start_server(params)

    @classmethod
    def host_client(cls, entity, privkeys, host_keys, host, port=22):
        """Starts a client for outgoing host/host communications"""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host_keys, Keys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'username': entity.id,
            'client_username': entity.id,
            'host': host,
            'port': port,
            'client_keys': [cls._private_key(privkeys)],
            'known_hosts': cls.__known_host(host_keys),
            'client_factory': SSHClient
        } + cls.ALGS

        cls.__start_client(params)

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
        } + cls.ALGS + cls.SARGS

        cls.__start_server(params)

    @classmethod
    def portal_client(cls, entity, privkeys, host_keys, host, port=22):
        """Starts a client for outgoing client/portal communications"""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(host_keys, Keys)
        Util.is_type(host, str)
        Util.is_type(port, int)

        params = {
            'username': entity.id,
            'client_username': entity.id,
            'host': host,
            'port': port,
            'client_keys': [cls._private_key(privkeys)],
            'known_hosts': cls.__known_host(host_keys),
            'client_factory': SSHClient
        } + cls.ALGS

        cls.__start_client(params)

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
        } + cls.ALGS + cls.SARGS

        cls.__start_server(params)

    @classmethod
    def boot_server(cls, host, port=22):
        """Starts a shell server for incoming boot communications"""
        pass

    @classmethod
    def __start_server(cls, params):
        async def run_server():
            await asyncssh.create_server(**params)

        loop = asyncio.get_event_loop()
        try:
            loop.run_until_complete(run_server())
        except (OSError, asyncssh.Error) as exc:
            logging.critical('Error starting server: %s' % str(exc))
        loop.run_forever()

    @classmethod
    def __start_client(cls, params):
        async def run_client():
            conn, client = await asyncssh.create_connection(**params)
            # chan, session = await conn.create_session(SSHClientSession)
            # await chan.wait_closed()
            conn.close()

        try:
            asyncio.get_event_loop().run_until_complete(run_client())
        except (OSError, asyncssh.Error) as exc:
            logging.critical('SSH connection failed: %s' % str(exc))

    @classmethod
    def __known_host(cls, host_keys):
        def callback(h, a, p):
            return (
                [NaClKey(key=NaClPublicKey.construct(
                    base64.b64decode(host_keys.verify)))], [], [])
        return callback

    @classmethod
    def _public_key(cls, keys):
        return NaClKey(key=NaClPublicKey.construct(
            base64.b64decode(keys.verify)))

    @classmethod
    def _private_key(cls, privkeys):
        return NaClKey(key=NaClPrivateKey.construct(
            base64.b64decode(privkeys.seed)))
