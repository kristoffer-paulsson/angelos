"""Module docstring."""
import asyncio
import logging

import asyncssh


class SSHServer(asyncssh.SSHServer):
    def __init__(self, client_keys=()):
        self._conn = None
        self._client_keys = client_keys

    def connection_made(self, conn):
        logging.info('Connection made')
        self._conn = conn
        conn.send_auth_banner('auth banner')

    def connection_lost(self, exc):
        if isinstance(exc, type(None)):
            logging.info('Connection closed')
        else:
            logging.error('Connection closed unexpectedly: %s' % str(exc))

    def debug_msg_received(self, msg, lang, always_display):
        logging.error('Error: %s' % str(msg))

    def begin_auth(self, username):
        logging.info('Begin authentication for: %s' % username)
        # Load keys for username
        return True

    def auth_completed(self):
        logging.info('Authentication completed')

    def public_key_auth_supported(self):
        return True

    def validate_public_key(self, username, key):
        logging.info('Authentication for a user')
        logging.debug('%s' % username)

    def session_requested(self):
        logging.debug('Session requested')
        return False

    def connection_requested(self, dest_host, dest_port, orig_host, orig_port):
        logging.debug('Connection requested')
        return False

    def server_requested(self, listen_host, listen_port):
        logging.debug('Server requested')
        return False


class SSHClient(asyncssh.SSHClient):
    def __init__(self, keylist=(), delay=1):
        self._keylist = keylist
        self._delay = delay

    def connection_made(self, conn):
        logging.info('Connection made')
        # chan, session = await conn.create_session(SSHClientSession)
        # await chan.wait_closed()

    def connection_lost(self, exc):
        if isinstance(exc, type(None)):
            logging.info('Connection closed')
        else:
            logging.error('Connection closed unexpectedly: %s' % str(exc))

    def debug_msg_received(self, msg, lang, always_display):
        logging.error('Error: %s' % str(msg))

    def auth_banner_received(self, msg, lang):
        logging.info('Banner: %s' % str(msg))

    def auth_completed(self):
        logging.info('Authentication completed')

    def public_key_auth_requested(self):
        if self._delay:
            yield from asyncio.sleep(self._delay)
        logging.info('Public key authentication requested')
        return self._keylist.pop(0) if self._keylist else None
