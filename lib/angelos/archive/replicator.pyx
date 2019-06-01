# cython: language_level=3
"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring.
"""
import asyncio
import datetime
import logging

from ..utils import Util
from .helper import Globber
from .archive7 import Archive7


class Replicator:
    @classmethod
    def difference(cls, master, slave):
        Util.is_type(master, Archive7)
        Util.is_type(slave, Archive7)

        m_list = Globber.full(master, '*')
        s_list = Globber.full(slave, '*')

        m_idxs = set(m_list.keys())
        s_idxs = set(s_list.keys())

        common = m_idxs & s_idxs
        m_unique = m_idxs - s_idxs
        s_unique = s_idxs - m_idxs

        pull = []
        push = []

        for i in m_unique:
            if not m_list[i][1]:
                push.append((i, b'c'))

        for i in s_unique:
            if not s_list[i][1]:
                pull.append((i, b'c'))

        for i in common:
            if m_list[i][2] > s_list[i][2]:
                if m_list[i][1]:
                    push.append((i, b'd'))
                else:
                    push.append((i, b'u'))
            elif m_list[i][2] < s_list[i][2]:
                if s_list[i][1]:
                    pull.append((i, b'd'))
                else:
                    pull.append((i, b'u'))

        return push, pull

    @classmethod
    def _copy(cls, frm, to, p_list, modify=False):
        for idx, op in p_list:
            if op == b'd':
                to.remove(idx)
            elif op == b'u':
                data = frm.load(idx)
                if not modify:
                    e = frm.info(idx)
                    to.save(idx, data, modified=e.modified)
                else:
                    to.save(idx, data)
            elif op == b'c':
                e = frm.info(idx)
                data = frm.load(idx)
                to.mkfile(
                    idx, data, created=e.created, owner=e.owner,
                    id=e.id, modified=(
                        e.modified if not modify else datetime.datetime.now()))
            else:
                logging.error('Unkown synchronization operation: %s' % str(op))
                raise RuntimeError(
                    'Unkown synchronization operation: %s' % str(op))

    @classmethod
    def push(cls, master, slave, p_list):
        cls._copy(master, slave, p_list)

    @classmethod
    def pull(cls, master, slave, p_list):
        cls._copy(slave, master, p_list)

    @classmethod
    def synchronize(cls, master, slave, modify=False):
        Util.is_type(master, Archive7)
        Util.is_type(slave, Archive7)

        push, pull = cls.difference(master, slave)
        cls._copy(master, slave, push, modify)
        cls._copy(slave, master, pull, modify)


class SyncClient:
    def __init__(self, reader, writer):
        self.__reader = reader
        self.__writer = writer

    def run(self):
        # Close connection when done
        self.__writer.close()

    @staticmethod
    async def client(address, port):
        Util.is_type(address, str)
        Util.is_type(port, int)

        reader, writer = await asyncio.open_connection(address, port)
        SyncClient(reader, writer).run()


class SyncServer:
    def __init__(self, reader, writer):
        self.__reader = reader
        self.__writer = writer

    def run(self):
        # Close connection when done
        self.__writer.close()

    @staticmethod
    async def server(address, port):
        Util.is_type(address, str)
        Util.is_type(port, int)

        async def handle(reader, writer):
            SyncServer(reader, writer).run()

        server = await asyncio.start_server(handle, address, port)
        async with server:
            await server.serve_forever()
