# cython: language_level=3
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
import gzip
import json
import logging
import time

from asyncssh import SSHClient, SSHClientSession, create_connection
from asyncssh.stream import SSHStreamSession
from angelos.lib.ioc import ContainerAware, Container
from angelos.common.misc import Loop

from angelos.lib.net.subsystem import SubsystemClient


class ClientSession(SSHStreamSession, SSHClientSession):
    def connection_made(self, chan):
        logging.debug("Session opened")
        self._chan = chan
        self._requests = dict()

    def connection_lost(self, exc):
        logging.debug("Connection lost")
        logging.debug(f"{exc}")

    def session_started(self):
        logging.debug("Session successful")

    def data_received(self, data, datatype):
        logging.debug(f"Received data: {data}")

        try:
            data = json.loads(gzip.decompress(data).decode('utf-8'))

            if data['request_id'] in self._requests:
                if callable(self._requests[data['request_id']]):
                    self._requests[data['request_id']](data)

                if self._requests[data['request_id']] is None:
                    self._requests[data['request_id']] = data
                else:
                    del (self._requests[data['request_id']])

        except Exception:
            logging.exception(f"There was an error processing the server response")

    def eof_received(self):
        logging.debug("Received EOF")
        self._chan.exit(0)

    async def send_request(self, verb, resource, body, callback):
        if verb not in ['GET', 'STORE', 'UPDATE', 'DELETE']:
            raise ValueError("Unknown verb")

        request = {
            'id': time.time(),
            'verb': verb,
            'resource': resource,
            'body': body
        }

        self._requests[request['id']] = callback
        self._chan.write(gzip.compress(json.dumps(request, separators=[',', ':']).encode('utf-8')))
        logging.debug(f"{verb} {resource} {body}")

        return request['id']


class Client(ContainerAware, SSHClient):
    """Client base class.

    Subsystems should be regiested in the _subsystems dictionary accordingly:
        self._subsystems["subsystem"] = (ClientSubsystemHandler, SubsystemClient)

    # Do something
    def something(self, arg1, arg2, callback=None):
        self._loop.run(
            self._session.send_request("WHATEVER", arg1, arg2, callback))
    """

    def __init__(self, ioc: Container):
        ContainerAware.__init__(self, ioc)

        self._connection = None
        self._session = None
        self._subsystems = dict()

    @classmethod
    async def connect(
            cls, ioc: Container, host: str, port: int,
            client_keys = None, known_hosts = None
    ) -> "Client":
        """Connect to a server with this client"""
        _, owner = await create_connection(
            lambda: cls(ioc),
            host,
            port,
            client_keys=client_keys,
            known_hosts=known_hosts
        )

        return owner

    async def _start_subsystem(self, subsystem: str) -> SubsystemClient:
        """Request a subsystem from the server."""
        if subsystem not in self._subsystems.keys():
            return None

        handler_cls, client_cls = self._subsystems[subsystem]
        writer, reader, _ = await self._connection.open_session(
            subsystem=subsystem, encoding=None)

        handler = handler_cls(Loop.main().loop, reader, writer)
        await handler.start()
        self._connection.create_task(handler.receive_packets(), handler.logger)
        return client_cls(self.ioc, handler)

    def connection_made(self, conn):
        """Connected to server."""
        self._connection = conn

    def auth_completed(self):
        """Completed authentication."""
        logging.debug('Authentication successful')
