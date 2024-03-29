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
"""
Replication endpoints. The endpoints binds the handlers and the business logic
of the clients and servers.
"""

from angelos.lib.ioc import ContainerAware


class ReplicatorClient(ContainerAware):
    """Replicator client."""

    def __init__(self, ioc, preset, modified=None):
        ContainerAware.__init__(self, ioc)
        self._preset = preset
        # self._archive = self.ioc.facade.archive(self._preset.archive)
        # self._modified = modified if modified else datetime.datetime(1, 1, 1)
        # self._path = self._preset.path
        # self._owner = uuid.UUID(int=0)
        # self._list = None
        # self._processed = set()

    @property
    def preset(self):
        return self._preset

    def __enter__(self):
        return self

    def __exit__(self, *exc_info):
        self.exit()

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc_info):
        self.__exit__()
        await self.wait_closed()


class ReplicatorServer(ContainerAware):
    """Replicator server."""

    def __init__(self, ioc, conn, portfolio):
        ContainerAware.__init__(self, ioc)
        self._conn = conn
        self._portfolio = portfolio

    @property
    def portfolio(self):
        """The portfolio associated with this Replicator server session"""
        return self._portfolio

    @property
    def channel(self):
        """The channel associated with this Replicator server session"""
        return self._chan

    @channel.setter
    def channel(self, chan):
        """Set the channel associated with this Replicator server session"""
        self._chan = chan

    @property
    def connection(self):
        """The channel associated with this SFTP server session"""
        return self._chan.get_connection()

    @property
    def env(self):
        """
        The environment associated with this Replicator server session
          This method returns the environment set by the client
          when this Replicator session was opened.
        """
        return self._chan.get_environment()

    @property
    def logger(self):
        """A logger associated with this SFTP server"""

        return self._chan.logger

    def exit(self):
        """Shut down this Replicator server"""

        pass
