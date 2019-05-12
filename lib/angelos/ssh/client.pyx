# cython: language_level=3
"""Module docstring."""
import logging

from ..starter import Starter
from .ssh import SSHServer


class ClientsServer(SSHServer):
    """SSH Server for the clients."""

    def begin_auth(self, username):
        logging.info('Begin authentication for: %s' % username)

        auth = self.ioc.load_client_auth(username)
        if auth[0] and auth[1] and auth[2]:
            self._client_keys = [Starter.public_key(key) for key in auth[0]]
            return True
        else:
            return False

    def validate_public_key(self, username, key):
        logging.info('Authentication for a user')
        logging.debug('%s' % username)
        return key in self._client_keys

    def session_requested(self):
        logging.debug('Session requested')
        # return AdminServerProcess(self.terminal, self.ioc.session)
        return False
