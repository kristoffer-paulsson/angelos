# cython: language_level=3, linetrace=True
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
"""Module docstring."""
import asyncio
import uuid
import logging

import asyncssh

from angelos.common.utils import Util
from angelos.lib.ioc import ContainerAware, LogAware


class SSHServer(LogAware, asyncssh.SSHServer):
    """SSH server container aware baseclass."""

    def __init__(self, ioc):
        """Initialize AdminServer."""
        self._conn = None
        self._client_keys = ()
        LogAware.__init__(self, ioc)

    def connection_made(self, conn):
        logging.info("Connection made")
        self._conn = conn
        # conn.send_auth_banner("auth banner")

    def connection_lost(self, exc):
        if isinstance(exc, type(None)):
            logging.info("Connection closed")
        else:
            logging.error("Connection closed unexpectedly: %s" % str(exc))
            logging.exception(exc, exc_info=True)

    def debug_msg_received(self, msg, lang, always_display):
        logging.error("Error: %s" % str(msg))

    def begin_auth(self, username):
        logging.info("Begin authentication for: %s" % username)
        # Load keys for username
        return True

    def auth_completed(self):
        logging.info("Authentication completed")

    def public_key_auth_supported(self):
        return True

    def validate_public_key(self, username, key):
        return False  # Security countermeasure

    def session_requested(self):
        logging.debug("Session requested")
        return False

    def connection_requested(self, dest_host, dest_port, orig_host, orig_port):
        logging.debug("Connection requested")
        return False

    def server_requested(self, listen_host, listen_port):
        logging.debug("Server requested")
        return False


class SSHClient(ContainerAware, asyncssh.SSHClient):
    def __init__(self, ioc, keylist=(), delay=1):
        """Initialize Client."""
        self._connection = None
        self._channel = None
        self._session = None
        self._keylist = keylist
        self._delay = delay
        ContainerAware.__init__(self, ioc)

    def connection_made(self, conn):
        logging.info("Connection made")
        self._connection = conn
        # self._channel, self._session =
        #   await conn.create_session(SSHClientSession)
        # chan, session = await conn.create_session(SSHClientSession)
        # await chan.wait_closed()

    def connection_lost(self, exc):
        if isinstance(exc, type(None)):
            logging.info("Connection closed")
        else:
            logging.error("Connection closed unexpectedly: %s" % str(exc))
            logging.exception(exc, exc_info=True)

    def debug_msg_received(self, msg, lang, always_display):
        logging.error("Error: %s" % str(msg))

    def auth_banner_received(self, msg, lang):
        logging.info("Banner: %s" % str(msg))

    def auth_completed(self):
        logging.info("Authentication completed")

    async def public_key_auth_requested(self):
        if self._delay:
            await asyncio.sleep(self._delay)
        logging.info("Public key authentication requested")
        return self._keylist.pop(0) if self._keylist else None


class SessionHandle:
    """Handle for a SSH Session."""

    def __init__(self, user_id, session):
        """Init the handle."""
        Util.is_type(user_id, uuid.UUID)
        Util.is_type(session, asyncssh.session.SSHSession)

        self.id = user_id
        self.session = session
        self.idle = 0

    def __del__(self):
        """Delete the handle including session."""
        self.session.close(sessmgr=True)
        del self.session
        del self.id


class SessionManager:
    """Session manager to be used with the IoC."""

    def __init__(self):
        """Init session manager."""
        self.__servers = {}
        self.__servsess = {}
        self.__sessions = {}

    def length(self):
        return len(self.__sessions)

    def reg_server(self, name, server, idle=60):
        """register a server with the manager."""
        Util.is_type(name, str)
        Util.is_type(server, asyncio.base_events.Server)
        Util.is_type(idle, int)

        if name in self.__servers.keys():
            # If server name not registered raise Error
            raise RuntimeError("Can not register a server twice")

        self.__servers[name] = (server, idle)  # Get server into registry
        self.__servsess[name] = set()  # Set server/session association

    async def unreg_server(self, name):
        """Unregister server and close all related sessions."""
        if name not in self.__servers.keys():
            # If server name not registered raise Error
            raise RuntimeError(
                "Can not register session on non-registered server"
            )

        # server = self.__servers[name][0]  # Get server instance by name
        self.__servers.pop(name)  # Remove server instance from registry

        for handle in self.__servsess[name]:  # Each session assoc with server
            del self.__sessions[handle.id]  # Remove session
            del handle  # Delete session

        del self.__servsess[name]  # Remove server/session association

    def add_session(self, name, handle):
        """Add a new session to related server."""
        if name not in self.__servers.keys():
            # Server for session must exist
            raise RuntimeError(
                "Can not register session on non-registered server"
            )

        if handle.id in self.__sessions.keys():
            # Session can only be added once.
            raise RuntimeError("Can not register session twice.")

        self.__sessions[handle.id] = handle  # Register session in registry
        self.__servsess[name].add(handle)  # Associate session with server

    def close_session(self, user_id):
        """Close a specific session."""
        if user_id not in self.__sessions.keys():
            return  # If session doesn't exist, pretend to close.

        handle = self.__sessions[user_id]  # Get session by user id
        del self.__sessions[user_id]

        for name in self.__servsess.keys():  # Remove session/server assoc
            try:
                self.__servsess[name].remove(handle)
            except KeyError:
                pass

        del handle  # Delete session handle. Handle will close session on del
