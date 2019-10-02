# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring."""
import logging

from .ssh import SSHServer
from .nacl import NaClKey


class HostsServer(SSHServer):
    """SSH Server for the hosts."""

    def begin_auth(self, username):
        logging.info("Begin authentication for: %s" % username)

        auth = self.ioc.load_host_auth(username)
        if auth[0] and auth[1] and auth[2] and auth[3]:
            self._client_keys = [NaClKey.factory(key) for key in auth[0]]

        return True

    def validate_public_key(self, username, key):
        logging.info("Authentication for a user")
        logging.debug("%s" % username)
        return key in self._client_keys

    def session_requested(self):
        logging.debug("Session requested")
        # return AdminServerProcess(self.terminal, self.ioc.session)
        return False
