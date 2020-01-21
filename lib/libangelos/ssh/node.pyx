# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import logging

from libangelos.ssh.ssh import SSHServer
from libangelos.ssh.nacl import NaClKey


class NodesServer(SSHServer):
    """SSH Server for the nodes."""

    def begin_auth(self, username):
        logging.info("Begin authentication for: %s" % username)

        auth = self.ioc.load_node_auth(username)
        if auth[0]:
            self._client_keys = [NaClKey.factory(self.ioc.facade.keys)]

        return True

    def validate_public_key(self, username, key):
        logging.info("Authentication for a user")
        logging.debug("%s" % username)
        return key in self._client_keys

    def session_requested(self):
        logging.debug("Session requested")
        # return AdminServerProcess(self.terminal, self.ioc.session)
        return False
