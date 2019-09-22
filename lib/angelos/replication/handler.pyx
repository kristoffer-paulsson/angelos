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

from asyncssh import Error
from asyncssh.packet import (
    SSHPacketHandler, PacketDecodeError, SSHPacket, Byte, UInt32, String,
    Boolean)
from .preset import Preset


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

    @property
    def client(self):
        """Property access to the client."""
        return self._client

    @asyncio.coroutine
    async def start(self):
        """Start a new replication operation."""
        try:
            print('send INIT')
            self.send_packet(Packets.RPL_INIT, None, UInt32(VERSION))

            try:
                # Wait for RPL_VERSION
                print('wait VERSION')
                packet = await self.recv_packet()
                pkttype = packet.get_byte()

                self._process_version(pkttype, None, packet)

                # Wait for RPL_CONFIRM
                print('wait CONFIRM')
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
            await self.send_packet(Packets.RPL_CLOSE, None)

        except Exception:
            logging.exception('Client replication failure')
            raise

    async def pull(self):
        """Synchronize using pull from the server."""
        run = True

        while run:
            print('send REQUEST pull')
            self.send_packet(Packets.RPL_REQUEST, None, String('pull'))

            print('wait RESPONSE / DONE')
            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if pkttype == Packets.RPL_DONE:
                self._process_done(pkttype, None, packet)
                run = False
                break

            s_fileinfo = self._process_response(pkttype, None, packet)

            s_full_path = self.client.preset.to_absolute(s_fileinfo.path)

            # Load file metadata
            c_fileinfo = self.client.preset.pull_file_meta()
            self.client.preset.file_processed(c_fileinfo.fileid)

            c_rel_path = self.client.preset.to_relative(c_fileinfo.path)

            # Calculate what action to take based on client and server
            # file circumstances.
            if not c_fileinfo.fileid:
                if s_fileinfo.deleted:
                    s_fileinfo.action = Actions.NO_ACTION
                else:
                    s_fileinfo.action = Actions.CLI_CREATE
            elif c_fileinfo.fileid and c_fileinfo.deleted:
                if s_fileinfo.deleted:
                    s_fileinfo.action = Actions.NO_ACTION
                else:
                    if c_fileinfo.modified > c_fileinfo.modified:
                        s_fileinfo.action = Actions.SER_DELETE
                    else:
                        s_fileinfo.action = Actions.CLI_UPDATE
            elif c_fileinfo.fileid and not c_fileinfo.deleted:
                if s_fileinfo.deleted:
                    if c_fileinfo.modified > s_fileinfo.modified:
                        s_fileinfo.action = Actions.SER_UPDATE
                    else:
                        s_fileinfo.action = Actions.CLI_DELETE
                else:
                    if c_fileinfo.modified > s_fileinfo.modified:
                        s_fileinfo.action = Actions.SER_UPDATE
                    else:
                        s_fileinfo.action = Actions.CLI_UPDATE
            else:
                s_fileinfo.action = Actions.NO_ACTION

            print('send SYNC')
            self.send_packet(
                Packets.RPL_SYNC, None, String(s_fileinfo.action),
                String(c_fileinfo.fileid.bytes), String(c_rel_path),
                String(c_fileinfo.modified.isoformat()),
                Boolean(c_fileinfo.deleted))

            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if not self._process_confirm(pkttype, None, packet):
                # raise Error(
                #   reason='File sync action not confirmed by server.', code=1)
                self._fileinfo = None
                continue
            else:
                self._fileinfo = s_fileinfo

            if self._fileinfo.action == Actions.CLI_CREATE:
                await self.download()
            elif self._fileinfo.action == Actions.CLI_UPDATE:
                await self.download()
            elif self._fileinfo.action == Actions.SER_UPDATE:
                await self.upload()
            elif self._fileinfo.action == Actions.CLI_DELETE:
                await self.delete()
            else:
                pass

            self._fileinfo = Actions.NO_ACTION

    async def push(self):
        """Synchronize using push to the server."""
        run = True

        while run:
            # Load file metadata
            c_fileid = ''
            c_path = ''
            c_modified = ''
            c_deleted = ''

            print('send REQUEST push')
            self.send_packet(
                Packets.RPL_REQUEST, None, String('push'),
                String(c_fileid.bytes), String(c_path),
                String(c_modified.isoformat()), Boolean(c_deleted))

            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if pkttype == Packets.RPL_DONE:
                self._process_done(pkttype, None, packet)
                run = False
                break

            s_fileid, s_path, s_modified, s_deleted = self._process_response(
                pkttype, None, packet)

            # Calculate what action to take based on client and server
            # file circumstances.
            if not s_fileid:
                if c_deleted:
                    self._action = Actions.NO_ACTION
                else:
                    self._action = Actions.SER_CREATE
            elif s_fileid and s_deleted:
                if c_deleted:
                    self._action = Actions.NO_ACTION
                else:
                    if s_modified > c_modified:
                        self._action = Actions.CLI_DELETE
                    else:
                        self._action = Actions.SER_UPDATE
            elif s_fileid and not s_deleted:
                if c_deleted:
                    if s_modified > c_modified:
                        self._action = Actions.CLI_UPDATE
                    else:
                        self._action = Actions.SER_DELETE
                else:
                    if s_modified > c_modified:
                        self._action = Actions.CLI_UPDATE
                    else:
                        self._action = Actions.SER_UPDATE
            else:
                self._action = Actions.NO_ACTION

            self.send_packet(Packets.RPL_SYNC, None, String(self._action))

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
                await self.delete(s_fileid)
            else:
                pass

            self._action = Actions.NO_ACTION

    async def download(self) -> bool:
        self.send_packet(
            Packets.RPL_DOWNLOAD, None,
            String(self._fileinfo.fileid.bytes), String(self._fileinfo.path))

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        if not self._process_confirm(pkttype, None, packet):
            return

        self.send_packet(Packets.RPL_GET, None, String('meta'), UInt32(0))

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        data = b''
        self._process_chunk(pkttype, None, packet)

        for piece in range(self._fileinfo.pieces):
            self.send_packet(
                Packets.RPL_GET, None, String('data'), UInt32(piece))
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
        else:
            self.send_packet(Packets.RPL_ABORT, None)
            return False

        self.client.ioc.facade.replication.save_file(
            self._preset, self._fileinfo)
        return True

    async def upload(self) -> bool:
        # Load file from archive7
        self.client.ioc.facade.replication.load_file(
            self._preset, self._fileinfo)
        data = b''
        pieces = ''
        size = ''
        digest = ''

        self.send_packet(
            Packets.RPL_UPLOAD, None, String(fileid.bytes), String(path),
            UInt32(size))

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        if not self._process_confirm(pkttype, None, packet):
            return

        self.send_packet(
            Packets.RPL_PUT, None, String('meta'), UInt32(pieces),
            UInt32(size), String(digest))

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        self._process_received(pkttype, None, packet)

        for piece in range(pieces):
            offset = piece*CHUNK_SIZE
            self.send_packet(
                Packets.RPL_PUT, None, String('data'), UInt32(piece),
                String(data[offset:offset+CHUNK_SIZE]))
            packet = await self.recv_packet()
            pkttype = packet.get_byte()
            rpiece = self._process_received(pkttype, None, packet)
            if rpiece != piece:
                raise Error(reason='Received wrong piece of data', code=1)

        self.send_packet(Packets.RPL_DONE, None)
        self.client.file_meta(fileid)

        return True

    async def delete(self, fileid: uuid.UUID, path: str) -> bool:
        # Delete file from Archive7
        self.client.file_meta(fileid)
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
        if version != VERSION:
            raise Error(reason='Unsupported version: %d' % version, code=1)

        packet.check_end()
        preset = self.client.preset

        if preset.preset != 'custom':
            print('send OPERATION:', preset.preset)
            self.send_packet(
                Packets.RPL_OPERATION, None, UInt32(VERSION),
                String(preset.modified.isoformat()),
                String(preset.preset))
        else:
            print('send OPERATION custom')
            self.send_packet(
                Packets.RPL_OPERATION, None, UInt32(VERSION),
                String(preset.modified.isoformat()),
                String(preset.preset),
                String(preset.archive),
                String(preset.path),
                String(preset.owner.bytes))

    def _process_confirm(
            self, pkttype: int, pktid: int, packet: SSHPacket) -> bool:
        """Process the server confirmation."""
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_CONFIRM:
            raise Error(reason='Expected confirm message', code=1)

        confirmation = packet.get_boolean()
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
            return self._fileinfo
        else:
            piece = packet.get_uint32()
            data = packet.get_string()

            packet.check_end()
            return piece, data

    def _process_received(self, pkttype: int, pktid: int, packet: SSHPacket):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_RECEIVED:
            raise Error(reason='Expected received message', code=1)

        meta = packet.get_string().decode()
        if meta == 'meta':
            packet.check_end()
            return True
        else:
            piece = packet.get_uint32()
            packet.check_end()
            return piece

    def _process_abort(self, pkttype: int, pktid: int, packet: SSHPacket):
        pass

    def _process_done(self, pkttype: int, pktid: int, packet: SSHPacket):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_DONE:
            raise Error(reason='Expected done message', code=1)

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
        self._modified = datetime.datetime(1, 1, 1)
        self._archive = None
        self._path = None
        self._owner = None
        self._action = Actions.NO_ACTION
        self._pieces = 0
        self._piece = 0

    async def run(self):
        """Replication server handler entry-point."""
        try:
            self._server.logger.info('Starting Replicator server')
            try:
                # Wait for RPL_INIT
                print('Wait INIT')
                packet = await self.recv_packet()
                pkttype = packet.get_byte()

                version = self._process_init(pkttype, None, packet)

                self.send_packet(Packets.RPL_VERSION, None, UInt32(VERSION))

                # Wait for RPL_OPERATION
                print('Wait OPERATION')
                packet = await self.recv_packet()
                pkttype = packet.get_byte()

                negotiated = self._process_operation(pkttype, None, packet)

                # Check protocol versions and presets of custom circumstances.
                self.send_packet(
                    Packets.RPL_CONFIRM, None, Boolean(negotiated == version))

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
                        print('wait REQUEST')
                        await self._process_request(pkttype, None, packet)
                    elif pkttype == Packets.RPL_CLOSE:
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

        packet.check_end()
        return version

    async def _process_request(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_REQUEST:
            raise Error(
                reason='Expected request message', code=1)

        _type = packet.get_string().decode()

        if _type == 'pull':
            print('perform PULL')
            await self.pulled()
        elif _type == 'push':
            print('perform PUSH')
            c_fileid = uuid.UUID(bytes=packet.get_string())
            c_path = packet.get_string().decode()
            c_modified = datetime.datetime.fromisoformat(
                packet.get_string().decode())
            c_deleted = packet.get_boolean()
            await self.pushed(c_fileid, c_path, c_modified, c_deleted)
        else:
            raise Error(
                reaseon='Unknown command %s, expected pull or push.' % _type,
                code=1)

    def _process_sync(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_SYNC:
            raise Error(reason='Expected sync message', code=1)

        action = packet.get_string().decode()
        if packet:
            fileid = uuid.UUID(bytes=packet.get_string())
            path = packet.get_string().decode()
            modified = datetime.datetime.fromisoformat(
                packet.get_string().decode())
            deleted = packet.get_boolean()
        else:
            fileid = None
            path = ''
            modified = None
            deleted = None

        packet.check_end()
        return action, fileid, path, modified, deleted

    def _process_download(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_DOWNLOAD:
            raise Error(reason='Expected download message', code=1)

        fileid = uuid.UUID(bytes=packet.get_string())
        path = packet.get_string().decode()
        packet.check_end()

        return fileid, path

    def _process_get(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_GET:
            raise Error(reason='Expected get message', code=1)

        _type = packet.get_string().decode()
        piece = packet.get_uint32()

        if _type == 'meta':
            # Get meta from loaded file
            pieces = ''
            self._pieces = ''
            size = ''
            digest = ''
            self.send_packet(
                Packets.RPL_CHUNK, None, UInt32(pieces), UInt32(size),
                String(digest))
        elif _type == 'data':
            # Get data from loaded file
            piece = ''
            data = ''
            self.send_packet(
                Packets.RPL_CHUNK, None, UInt32(piece), String(data))
        else:
            print(_type)
            raise Error(reason='Illegal get type.', code=1)

    def _process_upload(self, pkttype, pktid, packet):
        self.log_received_packet(pkttype, pktid, packet)

        if pkttype != Packets.RPL_UPLOAD:
            raise Error(reason='Expected upload message', code=1)

        fileid = uuid.UUID(bytes=packet.get_string())
        path = packet.get_string().decode()
        packet.check_end()

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
            # Store meta data
            self.send_packet(
                Packets.RPL_RECEIVED, None, String('meta'), UInt32(0),
                String(digest))
        elif _type == 'data':
            # Get data from loaded file
            piece = packet.get_uint32()
            data = packet.get_string()
            # Save data to file
            self.send_packet(
                Packets.RPL_RECEIVED, None, String('data'), UInt32(piece))
        else:
            raise Error(reason='Illegal put type.', code=1)

    def _process_done(self, pkttype, pktid, packet):
        pass

    def _process_close(self, pkttype, pktid, packet):
        pass

    async def pulled(self):
        # Load a file from archive7 to be pulled
        (s_fileid, s_path, s_modified, s_deleted
         ) = self._preset.pull_file_meta()
        self._preset.file_processed(s_fileid)

        s_rel_path = self._preset.to_relative(s_path)

        if s_fileid:
            self.send_packet(
                Packets.RPL_RESPONSE, None, String(s_fileid.bytes),
                String(s_rel_path), String(s_modified.isoformat()),
                Boolean(s_deleted))
        else:
            self.send_packet(Packets.RPL_DONE, None)
            return

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        action, c_fileid, c_path, c_modified, c_deleted = self._process_sync(
            pkttype, None, packet)

        c_full_path = self._preset.to_absolute(c_path)

        # Calculate what action to take based on client and server
        # file circumstances.
        if not c_fileid:
            if s_deleted:
                self._action = Actions.NO_ACTION
            else:
                self._action = Actions.CLI_CREATE
        elif c_fileid and c_deleted:
            if s_deleted:
                self._action = Actions.NO_ACTION
            else:
                if c_modified > s_modified:
                    self._action = Actions.SER_DELETE
                else:
                    self._action = Actions.CLI_UPDATE
        elif c_fileid and not c_deleted:
            if s_deleted:
                if c_modified > s_modified:
                    self._action = Actions.SER_UPDATE
                else:
                    self._action = Actions.CLI_DELETE
            else:
                if c_modified > s_modified:
                    self._action = Actions.SER_UPDATE
                else:
                    self._action = Actions.CLI_UPDATE
        else:
            self._action = Actions.NO_ACTION

        if self._action == action:
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(True))
        else:
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(False))
            return

        if self._action == Actions.SER_CREATE:
            await self.uploading(c_fileid, c_full_path)
        elif self._action == Actions.SER_UPDATE:
            await self.uploading(c_fileid, c_full_path)
        elif self._action == Actions.CLI_UPDATE:
            await self.downloading(s_fileid, c_full_path)
        elif self._action == Actions.SER_DELETE:
            await self.delete(s_fileid)
        else:
            pass

        self._action = Actions.NO_ACTION

    async def pushed(self, c_fileid, c_path, c_modified, c_deleted):
        # Load a file from archive7 to be pulled
        s_fileid = ''
        s_path = ''
        s_modified = ''
        s_deleted = ''

        self.send_packet(
            Packets.RPL_RESPONSE, None, String(s_fileid.bytes),
            String(s_path), String(s_modified.isoformat()),
            Boolean(s_deleted))

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        action, _, _, _, _ = self._process_sync(
            pkttype, None, packet)

        # Calculate what action to take based on client and server
        # file circumstances.
        if not s_fileid:
            if c_deleted:
                self._action = Actions.NO_ACTION
            else:
                self._action = Actions.SER_CREATE
        elif s_fileid and s_deleted:
            if c_deleted:
                self._action = Actions.NO_ACTION
            else:
                if s_modified > c_modified:
                    self._action = Actions.CLI_DELETE
                else:
                    self._action = Actions.SER_UPDATE
        elif s_fileid and not s_deleted:
            if c_deleted:
                if s_modified > c_modified:
                    self._action = Actions.CLI_UPDATE
                else:
                    self._action = Actions.SER_DELETE
            else:
                if s_modified > c_modified:
                    self._action = Actions.CLI_UPDATE
                else:
                    self._action = Actions.SER_UPDATE
        else:
            self._action = Actions.NO_ACTION

        if self._action == action:
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(True))
        else:
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(False))
            return

        if self._action == Actions.SER_CREATE:
            await self.uploading(c_fileid, c_path)
        elif self._action == Actions.SER_UPDATE:
            await self.uploading(c_fileid, c_path)
        elif self._action == Actions.CLI_UPDATE:
            await self.downloading(s_fileid, s_path)
        elif self._action == Actions.SER_DELETE:
            await self.delete(s_fileid)
        else:
            pass

        self._action = Actions.NO_ACTION

    async def downloading(self, fileid: uuid.UUID, path: str):
        print('wait DOWNLOAD')
        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        fileid, path = self._process_download(pkttype, None, packet)

        # Check whether file exists and is OK
        print('send CONFIRM DOWNLOAD')
        self.send_packet(
            Packets.RPL_CONFIRM, None, Boolean(True))

        print('wait GET')
        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        self._process_get(pkttype, None, packet)

        run = True
        while run:
            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if pkttype == Packets.RPL_DONE:
                run = False
                break

            self._process_get(pkttype, None, packet)

    async def uploading(self, fileid: uuid.UUID, path: str):
        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        fileid, path = self._process_upload(pkttype, None, packet)

        # Check whether file exists and is OK

        self.send_packet(
            Packets.RPL_CONFIRM, None, Boolean(True))

        packet = await self.recv_packet()
        pkttype = packet.get_byte()

        self._process_put(pkttype, None, packet)

        run = True
        while run:
            packet = await self.recv_packet()
            pkttype = packet.get_byte()

            if pkttype == Packets.RPL_DONE:
                run = False
                break

            self._process_put(pkttype, None, packet)
