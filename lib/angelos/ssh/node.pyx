# cython: language_level=3
"""Module docstring."""
import logging

from ..starter import Starter
from .ssh import SSHServer


class NodesServer(SSHServer):
    """SSH Server for the nodes."""

    def begin_auth(self, username):
        logging.info('Begin authentication for: %s' % username)

        do_auth = False
        # This function should also check host or ip.
        # self._conn._username
        # self._conn._local_addr
        # self._conn._peer_addr
        auth = self.ioc.load_node_auth(username)
        if auth[0]:
            self._client_keys = [Starter.public_key(self.ioc.facade.keys)]
            return True
        else:
            return False

        return do_auth

    def validate_public_key(self, username, key):
        logging.info('Authentication for a user')
        logging.debug('%s' % username)
        return key in self._client_keys

    def session_requested(self):
        logging.debug('Session requested')
        # return AdminServerProcess(self.terminal, self.ioc.session)
        return False
