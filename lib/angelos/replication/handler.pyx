# cython: language_level=3
"""

Copyright (c) 2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Replication handlers. The replication handlers contains the actual protocol
logic and handles the reading/writing and interpretation of replicator packets.
"""
import asyncio
import datetime
import uuid
import enum
import logging
import hashlib
import math

from asyncssh import Error
from asyncssh.packet import (
    SSHPacketHandler, PacketDecodeError, SSHPacket, Byte, UInt32, String,
    Boolean)
from .preset import Preset, FileSyncInfo


VERSION = 1


class Packets(enum.IntEnum):
    RPL_INIT = 1
    RPL_VERSION = 2
    RPL_OPERATION = 3
    RPL_CONFIRM = 4
    RPL_REQUEST = 5
    RPL_RESPONSE = 6
    RPL_DONE = 7
    RPL_SYNC = 8
    RPL_DOWNLOAD = 9
    RPL_GET = 10
    RPL_CHUNK = 11
    RPL_UPLOAD = 12
    RPL_PUT = 13
    RPL_RECEIVED = 14
    RPL_CLOSE = 15
    RPL_ABORT = 16


class Actions:
    CLI_CREATE = 'client-create'
    CLI_UPDATE = 'client-update'
    CLI_DELETE = 'client-delete'
    SER_CREATE = 'server-create'
    SER_UPDATE = 'server-update'
    SER_DELETE = 'server-delete'
    NO_ACTION = 'no-action'


CHUNK_SIZE = 2**15


class ReplicatorHandler(SSHPacketHandler):
    """Packet handler baseclass for the replicator."""

    def __init__(self, reader, writer):
        """Init the handler with packet reader and writer."""
        self._reader = reader
        self._writer = writer

        self._logger = reader.logger.get_child('replicator')

    async def _cleanup(self, exc):
        """Clean up this SFTP session"""
        if self._writer:
            self._writer.close()
            self._reader = None
            self._writer = None

    @property
    def logger(self):
        """The logger associated with this packet handler"""
        return self._logger

    async def _process_packet(self, pkttype, pktid, packet):
        """Abstract method for processing Replicator packets."""
        raise NotImplementedError

    def send_packet(self, pkttype, pktid, *args):
        """Send a Replicator packet."""
        payload = Byte(pkttype) + b''.join(args)

        try:
            self._writer.write(UInt32(len(payload)) + payload)
        except ConnectionError:
            logging.exception('Connection lost')
            raise
            # raise Error(reason='Connection lost', code=1) from None

        self.log_sent_packet(pkttype, pktid, payload)

    async def recv_packet(self):
        """Receive a Replicator packet."""
        pktlen = await self._reader.readexactly(4)
        pktlen = int.from_bytes(pktlen, 'big')

        packet = await self._reader.readexactly(pktlen)
        return SSHPacket(packet)

    async def recv_packets(self):
        """Receive and process Replicator packets."""
        try:
            while self._reader:
                packet = await self.recv_packet()

                pkttype = packet.get_byte()
                pktid = packet.get_uint32()

                self.log_received_packet(pkttype, pktid, packet)

                await self._process_packet(pkttype, pktid, packet)
        except PacketDecodeError as exc:
            await self._cleanup(Error('Bad packet.', str(exc)))
        except EOFError:
            await self._cleanup(None)
        except (OSError, Error) as exc:
            await self._cleanup(exc)


class ReplicatorClientHandler(ReplicatorHandler):
    _extensions = []

    def __init__(self, client, reader, writer):
        super().__init__(reader, writer)

        self._client = client
        self._version = None
        self._next_pktid = 0
        self._requests = {}

        self._packet_handler = {}
        self._packet_handler[Packets.RPL_VERSION] = self._process_version
        self._packet_handler[Packets.RPL_CONFIRM] = self._process_confirm
        self._packet_handler[Packets.RPL_RESPONSE] = self._process_response
        self._packet_handler[Packets.RPL_CHUNK] = self._process_chunk
        self._packet_handler[Packets.RPL_RECEIVED] = self._process_received
        self._packet_handler[Packets.RPL_ABORT] = self._process_abort
        self._packet_handler[Packets.RPL_DONE] = self._process_done

        self._preset = None
        self._filesync = None
        self._action = None

    @property
    def client(self):
        """Property access to the client."""
        return self._client

    @asyncio.coroutine
    async def start(self):
        """Start a new replication operation."""
        try:
            self.send_packet(Packets.RPL_INIT, None, UInt32(VERSION))
            logging.info('RPL_INIT sent')

            try:
                # Wait for RPL_VERSION
                packet = await self.recv_packet()
                pkttype = packet.get_byte()

                self._process_version(pkttype, None, packet)

                # Wait for RPL_CONFIRM
                packet = await self.recv_packet()
                pkttype = packet.get_byte()

                if not self._process_confirm(pkttype, None, packet):
                    raise Error(
                        reason='Operation not confirmed from server.', code=1)

                # Start syncro loop
                # Make client index/load file-list
                self.client.ioc.facade.replication.load_files_list(
                    self.client.preset)
                await self.pull()
                await self.push()

            except PacketDecodeError:
                logging.exception('Bad message')
                raise
                # raise Error(reason='Bad message', code=1)
            except (asyncio.IncompleteReadError, Error):
                logging.exception('Socket failure')
                raise
                # raise Error('Socket failure', code=1)

            # await self.send_packet(Packets.RPL_DONE, None)
            self.send_packet(Packets.RPL_CLOSE, None)
            logging.info('RPL_CLOSE sent')

        except Exception:
            logging.exception('Client replication failure')
            raise

    async def pull(self):
        """Synchronize using pull from the server."""
        run = True

        while run:
            self.send_packet(Packets.RPL_REQUEST, None, String('pull'))
            logging.info('RPL_REQUEST(pull) sent')

            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if pkttype == Packets.RPL_DONE:
                logging.info('RPL_DONE received')
                self._process_done(pkttype, None, packet)
                run = False
                break

            s_fileinfo = self._process_response(pkttype, None, packet)
            # s_full_path = self.client.preset.to_absolute(s_fileinfo.path)

            # Load file metadata
            c_fileinfo = self.client.preset.get_file_meta(s_fileinfo.owner)

            # Calculate what action to take based on client and server
            # file circumstances.
            if not c_fileinfo.fileid:
                if s_fileinfo.deleted:
                    self._action = Actions.NO_ACTION
                else:
                    self._action = Actions.CLI_CREATE
            elif c_fileinfo.fileid and c_fileinfo.deleted:
                if s_fileinfo.deleted:
                    self._action = Actions.NO_ACTION
                else:
                    if c_fileinfo.modified > c_fileinfo.modified:
                        self._action = Actions.SER_DELETE
                    else:
                        self._action = Actions.CLI_UPDATE
            elif c_fileinfo.fileid and not c_fileinfo.deleted:
                if s_fileinfo.deleted:
                    if c_fileinfo.modified > s_fileinfo.modified:
                        self._action = Actions.SER_UPDATE
                    else:
                        self._action = Actions.CLI_DELETE
                else:
                    if c_fileinfo.modified > s_fileinfo.modified:
                        self._action = Actions.SER_UPDATE
                    else:
                        self._action = Actions.CLI_UPDATE
            else:
                self._action = Actions.NO_ACTION

            if c_fileinfo.path:
                c_rel_path = self.client.preset.to_relative(c_fileinfo.path)
            else:
                c_rel_path = c_fileinfo.path
            self.send_packet(
                Packets.RPL_SYNC, None, String(self._action),
                String(c_fileinfo.fileid.bytes), String(c_rel_path),
                String(c_fileinfo.modified.isoformat()),
                Boolean(c_fileinfo.deleted))
            logging.info('RPL_SYNC(%s) sent' % self._action)

            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if not self._process_confirm(pkttype, None, packet):
                # raise Error(
                #   reason='File sync action not confirmed by server.', code=1)
                self._fileinfo = None
                continue
            else:
                self._fileinfo = s_fileinfo

            if self._action == Actions.CLI_CREATE:
                await self.download()
            elif self._action == Actions.CLI_UPDATE:
                await self.download()
            elif self._action == Actions.SER_UPDATE:
                await self.upload()
            elif self._action == Actions.CLI_DELETE:
                await self.delete()
            else:
                pass

            self.client.preset.file_processed(c_fileinfo.fileid)
            self._fileinfo = None
            self._action = None

    async def push(self):
        """Synchronize using push to the server."""
        run = True

        while run:
            # Load file metadata
            c_fileinfo = self.client.preset.pull_file_meta()
            self._fileinfo = c_fileinfo

            self.send_packet(
                Packets.RPL_REQUEST, None, String('push'),
                String(c_fileinfo.c_fileid.bytes), String(c_fileinfo.c_path),
                String(c_fileinfo.c_modified.isoformat()),
                Boolean(c_fileinfo.c_deleted))
            logging.info('RPL_REQUEST(push) sent')

            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if pkttype == Packets.RPL_DONE:
                logging.info('RPL_DONE received')
                self._process_done(pkttype, None, packet)
                run = False
                break

            s_fileinfo = self._process_response(pkttype, None, packet)

            # Calculate what action to take based on client and server
            # file circumstances.
            if not s_fileinfo.fileid:
                if c_fileinfo.deleted:
                    self._action = Actions.NO_ACTION
                else:
                    self._action = Actions.SER_CREATE
            elif s_fileinfo.fileid and s_fileinfo.deleted:
                if c_fileinfo.deleted:
                    self._action = Actions.NO_ACTION
                else:
                    if s_fileinfo.modified > c_fileinfo.modified:
                        self._action = Actions.CLI_DELETE
                    else:
                        self._action = Actions.SER_UPDATE
            elif s_fileinfo.fileid and not s_fileinfo.deleted:
                if c_fileinfo.deleted:
                    if s_fileinfo.modified > c_fileinfo.modified:
                        self._action = Actions.CLI_UPDATE
                    else:
                        self._action = Actions.SER_DELETE
                else:
                    if s_fileinfo.modified > c_fileinfo.modified:
                        self._action = Actions.CLI_UPDATE
                    else:
                        self._action = Actions.SER_UPDATE
            else:
                self._action = Actions.NO_ACTION

            self.send_packet(
                Packets.RPL_SYNC, None, String(self._action))
            logging.info('RPL_SYNC(%s) sent' % self._action)

            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if not self._process_confirm(pkttype, None, packet):
                # raise Error(
                #   reason='File sync action not confirmed by server.', code=1)
                self._action = Actions.NO_ACTION
                continue

            if self._action == Actions.SER_CREATE:
                await self.upload()
            elif self._action == Actions.SER_UPDATE:
                await self.upload()
            elif self._action == Actions.CLI_UPDATE:
                await self.download()
            elif self._action == Actions.CLI_DELETE:
                await self.delete()
            else:
                pass

            self.client.preset.file_processed(c_fileinfo.fileid)
            self._fileinfo = None
            self._action = None

    async def download(self) -> bool:
        self.send_packet(
            Packets.RPL_DOWNLOAD, None,
            String(self._fileinfo.fileid.bytes), String(self._fileinfo.path))
        logging.info('RPL_DOWNLOAD(%s) sent' % self._fileinfo.path)

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        if not self._process_confirm(pkttype, None, packet):
            return

        self.send_packet(Packets.RPL_GET, None, String('meta'), UInt32(0))
        logging.info('RPL_GET(meta) sent')

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        self._process_chunk(pkttype, None, packet)

        data = b''
        for piece in range(self._fileinfo.pieces):
            self.send_packet(
                Packets.RPL_GET, None, String('data'), UInt32(piece))
            logging.info('RPL_GET(data) sent')
            packet = await self.recv_packet()
            pkttype = packet.get_byte()
            rpiece, data = self._process_chunk(pkttype, None, packet)
            if rpiece != piece:
                raise Error(reason='Received wrong piece of data', code=1)
            self._fileinfo.data += data

        data = self._fileinfo.data
        if len(data) == self._fileinfo.size and hashlib.sha1(
                data).digest() == self._fileinfo.digest:
            self.send_packet(Packets.RPL_DONE, None)
            logging.info('RPL_DONE sent')
        else:
            self.send_packet(Packets.RPL_ABORT, None)
            logging.info('RPL_ABORT sent')
            return False

        self.client.ioc.facade.replication.save_file(
            self._preset, self._fileinfo)
        return True

    async def upload(self) -> bool:
        # Load file from archive7
        self.client.ioc.facade.replication.load_file(
            self._preset, self._fileinfo)

        self.send_packet(
            Packets.RPL_UPLOAD, None, String(self._fileinfo.fileid.bytes),
            String(self._fileinfo.path), UInt32(self._fileinfo.size))
        logging.info('RPL_UPLOAD(%s) sent' % self._fileinfo.path)

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        if not self._process_confirm(pkttype, None, packet):
            return

        self.send_packet(
            Packets.RPL_PUT, None, String('meta'),
            UInt32(self._fileinfo.pieces), String(self._fileinfo.digest),
            String(self._fileinfo.filename),
            String(self._fileinfo.created.isoformat()),
            String(self._fileinfo.modified.isoformat()),
            String(self._fileinfo.owner.bytes),
            String(self._fileinfo.user), String(self._fileinfo.group),
            String(self._fileinfo.perms.to_bytes(2, 'big'))
            )
        logging.info('RPL_PUT(meta) sent')

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        self._process_received(pkttype, None, packet)

        for piece in range(self._fileinfo.pieces):
            offset = piece*CHUNK_SIZE
            self.send_packet(
                Packets.RPL_PUT, None, String('data'), UInt32(piece),
                String(self._fileinfo.data[offset:offset+CHUNK_SIZE]))
            logging.info('RPL_PUT(data) sent')
            packet = await self.recv_packet()
            pkttype = packet.get_byte()
            rpiece = self._process_received(pkttype, None, packet)
            if rpiece != piece:
                raise Error(reason='Received wrong piece of data', code=1)

        self.send_packet(Packets.RPL_DONE, None)
        logging.info('RPL_DONE sent')
        return True

    async def delete(self) -> bool:
        # Delete file from Archive7
        self.client.ioc.facade.replication.del_file(
            self._preset, self._fileinfo)
        return True

    def _process_version(self, pkttype: int, pktid: int, packet: SSHPacket):
        """
        Process the server returned version and ask for carrying out an
        operation.
        """
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_VERSION:
            raise Error(reason='Expected version message', code=1)

        version = packet.get_uint32()
        logging.info('RPL_VERSION(%s) received' % version)
        if version != VERSION:
            raise Error(reason='Unsupported version: %d' % version, code=1)

        packet.check_end()
        preset = self.client.preset

        if preset.preset != 'custom':
            self.send_packet(
                Packets.RPL_OPERATION, None, UInt32(VERSION),
                String(preset.modified.isoformat()),
                String(preset.preset))
            logging.info('RPL_OPERATION(%s, %s) sent' % (
                preset.preset, VERSION))
        else:
            self.send_packet(
                Packets.RPL_OPERATION, None, UInt32(VERSION),
                String(preset.modified.isoformat()),
                String(preset.preset),
                String(preset.archive),
                String(preset.path),
                String(preset.owner.bytes))
            logging.info('RPL_OPERATION(%s, %s) sent' % (
                self._preset, VERSION))

    def _process_confirm(
            self, pkttype: int, pktid: int, packet: SSHPacket) -> bool:
        """Process the server confirmation."""
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_CONFIRM:
            raise Error(reason='Expected confirm message', code=1)

        confirmation = packet.get_boolean()
        logging.info('RPL_CONFIRM(%s) received' % confirmation)
        packet.check_end()

        return confirmation

    def _process_response(
            self, pkttype: int, pktid: int, packet: SSHPacket
            ) -> FileSyncInfo:
        """Process response from request and return file information."""
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_RESPONSE:
            raise Error(reason='Expected response message', code=1)

        fileinfo = FileSyncInfo()
        fileinfo.fileid = uuid.UUID(bytes=packet.get_string())
        fileinfo.path = packet.get_string().decode()
        fileinfo.modified = datetime.datetime.fromisoformat(
            packet.get_string().decode())
        fileinfo.deleted = packet.get_boolean()
        packet.check_end()
        logging.info('RPL_RESPONSE(%s) received' % fileinfo.path)

        return fileinfo

    def _process_chunk(self, pkttype: int, pktid: int, packet: SSHPacket):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_CHUNK:
            raise Error(reason='Expected data/meta chunk message', code=1)

        meta = packet.get_string().decode()
        if meta == 'meta':
            self._fileinfo.pieces = packet.get_uint32()
            self._fileinfo.size = packet.get_uint32()
            self._fileinfo.digest = packet.get_string()

            self._fileinfo.filename = packet.get_string().decode()
            self._fileinfo.created = datetime.datetime.fromisoformat(
                packet.get_string().decode())
            self._fileinfo.modified = datetime.datetime.fromisoformat(
                packet.get_string().decode())
            self._fileinfo.owner = uuid.UUID(bytes=packet.get_string())
            self._fileinfo.fileid = uuid.UUID(bytes=packet.get_string())
            self._fileinfo.user = packet.get_string()
            self._fileinfo.group = packet.get_string()
            self._fileinfo.perms = int.from_bytes(packet.get_bytes(2), 'big')

            packet.check_end()
            logging.info('RPL_CHUNK(meta, %s) received')
            return self._fileinfo
        if meta == 'data':
            piece = packet.get_uint32()
            data = packet.get_string()

            packet.check_end()
            logging.info('RPL_CHUNK(data, %s) received' % piece)
            return piece, data
        else:
            Error(reason='RPL_CHUNK expects meta or data. %s given.' % meta,
                  code=1)

    def _process_received(self, pkttype: int, pktid: int, packet: SSHPacket):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_RECEIVED:
            raise Error(reason='Expected received message', code=1)

        meta = packet.get_string().decode()
        if meta == 'meta':
            packet.check_end()
            logging.info('RPL_RECEIVED(meta) received')
            return True
        elif meta == 'data':
            piece = packet.get_uint32()
            packet.check_end()
            logging.info('RPL_RECEIVED(data, %s) received' % piece)
            return piece
        else:
            raise Error(reason='RPL_RECEIVED illegal, meta or data', code=1)

    def _process_abort(self, pkttype: int, pktid: int, packet: SSHPacket):
        pass

    def _process_done(self, pkttype: int, pktid: int, packet: SSHPacket):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_DONE:
            raise Error(reason='Expected done message', code=1)
        logging.info('RPL_DONE received')

    def exit(self):
        if self._writer:
            self._writer.write_eof()

    async def wait_closed(self):
        if self._writer:
            await self._writer.channel.wait_closed()


class ReplicatorServerHandler(ReplicatorHandler):
    """An SFTP server session handler"""

    def __init__(self, server, reader, writer):
        super().__init__(reader, writer)

        self._server = server
        self._version = None
        self._packet_handler = {}

        self._packet_handler[Packets.RPL_INIT] = self._process_init
        self._packet_handler[Packets.RPL_OPERATION] = self._process_operation
        self._packet_handler[Packets.RPL_REQUEST] = self._process_request
        self._packet_handler[Packets.RPL_SYNC] = self._process_sync
        self._packet_handler[Packets.RPL_DOWNLOAD] = self._process_download
        self._packet_handler[Packets.RPL_GET] = self._process_get
        self._packet_handler[Packets.RPL_UPLOAD] = self._process_upload
        self._packet_handler[Packets.RPL_PUT] = self._process_put
        self._packet_handler[Packets.RPL_DONE] = self._process_done
        self._packet_handler[Packets.RPL_CLOSE] = self._process_close

        self._preset = None
        self._fileinfo = None
        self._action = None

    async def run(self):
        """Replication server handler entry-point."""
        try:
            self._server.logger.info('Starting Replicator server')
            try:
                # Wait for RPL_INIT
                packet = await self.recv_packet()
                pkttype = packet.get_byte()

                version = self._process_init(pkttype, None, packet)

                self.send_packet(Packets.RPL_VERSION, None, UInt32(VERSION))
                logging.info('RPL_VERSION(%s) sent' % VERSION)

                # Wait for RPL_OPERATION
                packet = await self.recv_packet()
                pkttype = packet.get_byte()

                negotiated = self._process_operation(pkttype, None, packet)

                # Check protocol versions and presets of custom circumstances.
                confirm = (negotiated == version)
                self.send_packet(
                    Packets.RPL_CONFIRM, None, Boolean(confirm))
                logging.info('RPL_CONFIRM(%s) sent' % confirm)

                if negotiated != version:
                    raise Error(reason='Incompatible protocol version', code=1)

                # Loop for receiving pull/push
                self._server.ioc.facade.replication.load_files_list(
                    self._preset)

                run = True
                while run:
                    packet = await self.recv_packet()
                    pkttype = packet.get_byte()

                    if pkttype == Packets.RPL_REQUEST:
                        await self._process_request(pkttype, None, packet)
                    elif pkttype == Packets.RPL_CLOSE:
                        logging.info('RPL_CLOSE received')
                        run = False
                    else:
                        run = False

            except PacketDecodeError:
                logging.exception('Bad message')
                raise
                # raise Error(reason='Bad message', code=1)
            except (asyncio.IncompleteReadError, Error):
                logging.exception('Socket failure')
                raise
                # raise Error(reason='Socket failure', code=1)

        except Exception:
            logging.exception('Server repliction failure')
            raise

    def _process_init(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_INIT:
            raise Error(reason='Expected init message', code=1)

        version = packet.get_uint32()
        packet.check_end()
        logging.info('RPL_INIT(%s) received' % version)
        return version

    def _process_operation(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_OPERATION:
            raise Error(reason='Expected operation message', code=1)

        version = packet.get_uint32()
        modified = datetime.datetime.fromisoformat(
            packet.get_string().decode())
        preset_type = packet.get_string().decode()

        if preset_type == 'custom':
            archive = packet.get_string().decode()
            path = packet.get_string().decode()
            owner = uuid.UUID(bytes=packet.get_string())
            self._preset = self._server.ioc.facade.replication.create_preset(
                preset_type, Preset.SERVER, self._server.portfolio.entity.id,
                modified=modified, archive=archive, path=path, owner=owner)
        else:
            self._preset = self._server.ioc.facade.replication.create_preset(
                preset_type, Preset.SERVER, self._server.portfolio.entity.id,
                modified=modified)

        logging.info('RPL_OPERATION(%s) received' % version)
        packet.check_end()
        return version

    async def _process_request(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_REQUEST:
            raise Error(
                reason='Expected request message', code=1)

        _type = packet.get_string().decode()

        if _type == 'pull':
            packet.check_end()
            logging.info('RPL_OPERATION(pull) received')
            await self.pulled()
        elif _type == 'push':
            c_fileinfo = FileSyncInfo()
            c_fileinfo.fileid = uuid.UUID(bytes=packet.get_string())
            c_fileinfo.path = packet.get_string().decode()
            c_fileinfo.modified = datetime.datetime.fromisoformat(
                packet.get_string().decode())
            c_fileinfo.deleted = packet.get_boolean()
            packet.check_end()
            logging.info('RPL_REQUEST(push, %s) received' % c_fileinfo.path)
            await self.pushed(c_fileinfo)
        else:
            raise Error(
                reaseon='Unknown command %s, expected pull or push.' % _type,
                code=1)

    def _process_sync(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_SYNC:
            raise Error(reason='Expected sync message', code=1)

        action = packet.get_string().decode()
        fileinfo = FileSyncInfo()

        if packet:
            fileinfo.fileid = uuid.UUID(bytes=packet.get_string())
            fileinfo.path = packet.get_string().decode()
            fileinfo.modified = datetime.datetime.fromisoformat(
                packet.get_string().decode())
            fileinfo.deleted = packet.get_boolean()
            packet.check_end()
            logging.info('RPL_SYNC(%s, %s) received' % (action, fileinfo.path))
        else:
            packet.check_end()
            logging.info('RPL_SYNC(%s) received' % action)

        return action, fileinfo

    def _process_download(self, pkttype, pktid, packet) -> FileSyncInfo:
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_DOWNLOAD:
            raise Error(reason='Expected download message', code=1)

        fileinfo = FileSyncInfo()
        fileinfo.fileid = uuid.UUID(bytes=packet.get_string())
        fileinfo.path = packet.get_string().decode()
        packet.check_end()
        logging.info('RPL_DOWNLOAD(%s) received' % fileinfo.path)

        return fileinfo

    def _process_get(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_GET:
            raise Error(reason='Expected get message', code=1)

        _type = packet.get_string().decode()
        piece = packet.get_uint32()
        packet.check_end()
        logging.info('RPL_GET(%s, %s) received' % (_type, piece))

        if _type == 'meta':
            # Get meta from loaded file
            self._fileinfo.pieces = math.ceil(self._fileinfo.size / CHUNK_SIZE)
            self.send_packet(
                Packets.RPL_CHUNK, None, String('meta'),
                UInt32(self._fileinfo.pieces), UInt32(self._fileinfo.size),
                String(self._fileinfo.digest), String(self._fileinfo.filename),
                String(self._fileinfo.created.isoformat()),
                String(self._fileinfo.modified.isoformat()),
                String(self._fileinfo.owner.bytes),
                String(self._fileinfo.fileid.bytes),
                String(self._fileinfo.user), String(self._fileinfo.group),
                String(self._fileinfo.perms.to_bytes(2, 'big'))
                )
            logging.info('RPL_CHUNK(meta) sent')

        elif _type == 'data':
            # Get data from loaded file
            piece = ''
            data = ''
            self.send_packet(
                Packets.RPL_CHUNK, None, String('data'),
                UInt32(piece), String(data))
            logging.info('RPL_CHUNK(data) sent')
        else:
            raise Error(reason='Illegal get type.', code=1)

    def _process_upload(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_UPLOAD:
            raise Error(reason='Expected upload message', code=1)

        fileid = uuid.UUID(bytes=packet.get_string())
        path = packet.get_string().decode()
        packet.check_end()
        logging.info('RPL_UPLOAD(%s) received' % path)

        return fileid, path

    def _process_put(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_PUT:
            raise Error(reason='Expected put message', code=1)

        _type = packet.get_string().decode()
        piece = packet.get_uint32()
        if _type == 'meta':
            # Get meta from loaded file
            pieces = packet.get_uint32()
            self._pieces = pieces
            size = packet.get_uint32()
            digest = packet.get_string()
            packet.check_end()
            logging.info('RPL_PUT(meta) received')
            # Store meta data
            self.send_packet(
                Packets.RPL_RECEIVED, None, String('meta'), UInt32(0),
                String(digest))
            logging.info('RPL_RECEIVED(meta) sent')
        elif _type == 'data':
            # Get data from loaded file
            piece = packet.get_uint32()
            data = packet.get_string()
            packet.check_end()
            logging.info('RPL_PUT(data, %s) received' % piece)
            # Save data to file
            self.send_packet(
                Packets.RPL_RECEIVED, None, String('data'), UInt32(piece))
            logging.info('RPL_RECEIVED(data, %s) sent' % piece)
        else:
            raise Error(reason='Illegal put type.', code=1)

    def _process_done(self, pkttype, pktid, packet):
        pass

    def _process_close(self, pkttype, pktid, packet):
        pass

    async def pulled(self):
        # Load a file from archive7 to be pulled
        s_fileinfo = self._preset.pull_file_meta()
        if s_fileinfo.path:
            s_rel_path = self._preset.to_relative(s_fileinfo.path)
        else:
            s_rel_path = s_fileinfo.path

        if s_fileinfo.fileid:
            self.send_packet(
                Packets.RPL_RESPONSE, None, String(s_fileinfo.fileid.bytes),
                String(s_rel_path), String(s_fileinfo.modified.isoformat()),
                Boolean(s_fileinfo.deleted))
            logging.info('RPL_RESPONSE(%s) sent' % s_rel_path)
        else:
            self.send_packet(Packets.RPL_DONE, None)
            logging.info('RPL_DONE sent')
            return

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        action, c_fileinfo = self._process_sync(pkttype, None, packet)
        # c_full_path = self._preset.to_absolute(c_fileinfo.path)

        # Calculate what action to take based on client and server
        # file circumstances.
        if not c_fileinfo.fileid:
            if s_fileinfo.deleted:
                self._action = Actions.NO_ACTION
            else:
                self._action = Actions.CLI_CREATE
        elif c_fileinfo.fileid and c_fileinfo.deleted:
            if s_fileinfo.deleted:
                self._action = Actions.NO_ACTION
            else:
                if c_fileinfo.modified > s_fileinfo.modified:
                    self._action = Actions.SER_DELETE
                else:
                    self._action = Actions.CLI_UPDATE
        elif c_fileinfo.fileid and not c_fileinfo.deleted:
            if s_fileinfo.deleted:
                if c_fileinfo.modified > s_fileinfo.modified:
                    self._action = Actions.SER_UPDATE
                else:
                    self._action = Actions.CLI_DELETE
            else:
                if c_fileinfo.modified > s_fileinfo.modified:
                    self._action = Actions.SER_UPDATE
                else:
                    self._action = Actions.CLI_UPDATE
        else:
            self._action = Actions.NO_ACTION

        if self._action == action:
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(True))
            logging.info('RPL_CONFIRM(%s) sent' % True)
            self._fileinfo = s_fileinfo
        else:
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(False))
            logging.info('RPL_CONFIRM(%s) sent' % False)
            return

        if self._action == Actions.SER_CREATE:
            await self.uploading()
        elif self._action == Actions.SER_UPDATE:
            await self.uploading()
        elif self._action == Actions.CLI_UPDATE:
            await self.downloading()
        elif self._action == Actions.SER_DELETE:
            await self.delete()
        else:
            pass

        self._preset.file_processed(s_fileinfo.fileid)
        self._fileinfo = None
        self._action = None

    async def pushed(self, c_fileinfo: FileSyncInfo):
        # Load a file from archive7 to be pulled
        s_fileinfo = self._preset.get_file_meta(self._fileinfo.fileid)

        self.send_packet(
            Packets.RPL_RESPONSE, None, String(s_fileinfo.fileid.bytes),
            String(s_fileinfo.path), String(s_fileinfo.modified.isoformat()),
            Boolean(s_fileinfo.deleted))
        logging.info('RPL_RESPONSE(%s) sent' % s_fileinfo.path)

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        action = self._process_sync(pkttype, None, packet)

        # Calculate what action to take based on client and server
        # file circumstances.
        if not s_fileinfo.fileid:
            if c_fileinfo.deleted:
                self._action = Actions.NO_ACTION
            else:
                self._action = Actions.SER_CREATE
        elif s_fileinfo.fileid and s_fileinfo.deleted:
            if c_fileinfo.deleted:
                self._action = Actions.NO_ACTION
            else:
                if s_fileinfo.modified > c_fileinfo.modified:
                    self._action = Actions.CLI_DELETE
                else:
                    self._action = Actions.SER_UPDATE
        elif s_fileinfo.fileid and not s_fileinfo.deleted:
            if c_fileinfo.deleted:
                if s_fileinfo.modified > c_fileinfo.modified:
                    self._action = Actions.CLI_UPDATE
                else:
                    self._action = Actions.SER_DELETE
            else:
                if s_fileinfo.modified > c_fileinfo.modified:
                    self._action = Actions.CLI_UPDATE
                else:
                    self._action = Actions.SER_UPDATE
        else:
            self._action = Actions.NO_ACTION

        if self._action == action:
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(True))
            logging.info('RPL_CONFIRM(%s) sent' % True)
            self._fileinfo = c_fileinfo
        else:
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(False))
            logging.info('RPL_CONFIRM(%s) sent' % False)
            return

        if self._action == Actions.SER_CREATE:
            await self.uploading()
        elif self._action == Actions.SER_UPDATE:
            await self.uploading()
        elif self._action == Actions.CLI_UPDATE:
            await self.downloading()
        elif self._action == Actions.SER_DELETE:
            await self.delete()
        else:
            pass

        self._preset.file_processed(s_fileinfo.fileid)
        self._fileinfo = None
        self._action = None

    async def downloading(self):
        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        c_fileinfo = self._process_download(pkttype, None, packet)

        if c_fileinfo.fileid == self._fileinfo.fileid and (
                c_fileinfo.path == self._fileinfo.path):
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(True))
            logging.info('RPL_CONFIRM(%s) sent' % True)
        else:
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(False))
            logging.info('RPL_CONFIRM(%s) sent' % False)
            return

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        self._process_get(pkttype, None, packet)

        run = True
        while run:
            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if pkttype == Packets.RPL_DONE:
                logging.info('RPL_DONE received')
                run = False
                break

            self._process_get(pkttype, None, packet)

    async def uploading(self):
        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        fileid, path = self._process_upload(pkttype, None, packet)

        # Check whether file exists and is OK

        self.send_packet(Packets.RPL_CONFIRM, None, Boolean(True))
        logging.info('RPL_CONFIRM(%s) sent' % True)

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        self._process_put(pkttype, None, packet)

        run = True
        while run:
            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if pkttype == Packets.RPL_DONE:
                logging.info('RPL_DONE received')
                run = False
                break

            self._process_put(pkttype, None, packet)
