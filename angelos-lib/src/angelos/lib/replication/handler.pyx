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
Replication handlers. The replication handlers contains the actual protocol
logic and handles the reading/writing and interpretation of replicator packets.
"""
import asyncio
import datetime
import enum
import logging
import math
import uuid
from typing import Any

from angelos.common.utils import Util
from asyncssh import Error
from asyncssh.packet import (
    SSHPacketHandler,
    PacketDecodeError,
    SSHPacket,
    Byte,
    UInt32,
    String,
    Boolean,
)
from angelos.lib.error import AngelosException
from angelos.common.misc import ThresholdCounter

from angelos.lib.replication.preset import Preset, FileSyncInfo

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
    CLI_CREATE = "client-create"
    CLI_UPDATE = "client-update"
    CLI_DELETE = "client-delete"
    SER_CREATE = "server-create"
    SER_UPDATE = "server-update"
    SER_DELETE = "server-delete"
    NO_ACTION = "no-action"


CHUNK_SIZE = 2 ** 15


class PacketProcessor:
    def wait(self):
        pass

    def send(self):
        pass


class ReplicatorHandler(SSHPacketHandler):
    """Packet handler baseclass for the replicator."""

    def __init__(self, reader, writer):
        """Init the handler with packet reader and writer."""
        self._reader = reader
        self._writer = writer

        self._logger = reader.logger.get_child("replicator")
        self._aborted = False
        self._counter = ThresholdCounter(10)

        self._preset = None
        self._clientfile = None
        self._serverfile = None
        self._action = None
        self._chunk = None

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
        raise NotImplementedError()

    def send_packet(self, pkttype, pktid, *args):
        """Send a Replicator packet."""
        payload = Byte(pkttype) + b"".join(args)

        try:
            self._writer.write(UInt32(len(payload)) + payload)
        except ConnectionError as e:
            logging.error(e, exc_info=True)
            # logging.exception("Connection lost")
            raise Error(reason='Connection lost', code=1) from None

        self.log_sent_packet(pkttype, pktid, payload)

    async def recv_packet(self):
        """Receive a Replicator packet."""
        pktlen = int.from_bytes(await self._reader.readexactly(4), "big")
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
        except PacketDecodeError as e:
            logging.error(e, exc_info=True)
            await self._cleanup(Error("Bad packet.", str(e)))
        except EOFError as e:
            logging.error(e, exc_info=True)
            await self._cleanup(None)
        except (OSError, Error) as e:
            logging.error(e, exc_info=True)
            await self._cleanup(e)

    async def handle_packet(self, handlers: dict) -> (Any, int):
        packet = await self.recv_packet()
        pkttype = packet.get_byte()
        self.log_received_packet(pkttype, None, packet)

        if pkttype == Packets.RPL_ABORT:
            self._aborted = True
            self._counter.tick()
            logging.info('RPL_ABORT received')
            raise Error(reason="Received abort request", code=1)

        if pkttype not in handlers.keys():
            self._counter.reset()
            raise Error(reason="Packet handler missing", code=1)

        return await handlers[pkttype](packet), pkttype


class ReplicatorClientHandler(ReplicatorHandler):
    _extensions = []

    def __init__(self, client, reader, writer):
        super().__init__(reader, writer)

        self._client = client
        self._version = None
        self._next_pktid = 0

        self._packet_handler = {}
        self._packet_handler[Packets.RPL_VERSION] = self._process_version
        self._packet_handler[Packets.RPL_CONFIRM] = self._process_confirm
        self._packet_handler[Packets.RPL_RESPONSE] = self._process_response
        self._packet_handler[Packets.RPL_CHUNK] = self._process_chunk
        self._packet_handler[Packets.RPL_RECEIVED] = self._process_received
        self._packet_handler[Packets.RPL_ABORT] = self._process_abort
        self._packet_handler[Packets.RPL_DONE] = self._process_done

    @property
    def client(self):
        """Property access to the client."""
        return self._client

    @asyncio.coroutine
    async def start(self):
        """Start a new replication operation."""
        try:
            await self.client.preset.on_init(self.client.ioc)
            self.send_packet(Packets.RPL_INIT, None, UInt32(VERSION))
            logging.info("RPL_INIT sent")

            try:
                # Wait for RPL_VERSION
                await self.handle_packet(
                    {Packets.RPL_VERSION: self._process_version})

                # Wait for RPL_CONFIRM
                confirm, _ = await self.handle_packet({
                    Packets.RPL_CONFIRM: self._process_confirm})
                if not confirm:
                    raise Error(
                        reason="Operation not confirmed from server.", code=1
                    )

                # Start syncro loop
                # Make client index/load file-list
                await self.client.ioc.facade.api.replication.load_files_list(
                    self.client.preset
                )
                await self.pull()
                await self.push()

            except (asyncio.IncompleteReadError, PacketDecodeError, Error) as e:
                logging.error(e, exc_info=True)
                # logging.exception("Network error")
                raise

            # await self.send_packet(Packets.RPL_DONE, None)
            self.send_packet(Packets.RPL_CLOSE, None)
            logging.info("RPL_CLOSE sent")
            await self.client.preset.on_close(self.client.ioc)

            self.exit()
        except Exception as e:
            Util.print_exception(e)
            self.exit()
            logging.exception("Client replication failure")
            raise

    async def pull(self):
        """Synchronize using pull from the server."""
        while True:
            try:
                await self.client.preset.on_before_pull(self.client.ioc)
                self.send_packet(Packets.RPL_REQUEST, None, String("pull"))
                logging.info("RPL_REQUEST(pull) sent")

                s_fileinfo, pkttype = await self.handle_packet({
                    Packets.RPL_RESPONSE: self._process_response,
                    Packets.RPL_DONE: self._process_done
                })

                if pkttype == Packets.RPL_DONE:
                    break

                # Load file metadata
                c_fileinfo = self.client.preset.get_file_meta(
                    s_fileinfo.fileid)

                # Calculate what action to take based on client and server
                # file circumstances.
                if not c_fileinfo.fileid.int:
                    if s_fileinfo.deleted:
                        self._action = Actions.NO_ACTION
                    else:
                        self._action = Actions.CLI_CREATE
                elif c_fileinfo.fileid.int and c_fileinfo.deleted:
                    if s_fileinfo.deleted:
                        self._action = Actions.NO_ACTION
                    else:
                        if c_fileinfo.modified > s_fileinfo.modified:
                            self._action = Actions.SER_DELETE
                        else:
                            self._action = Actions.CLI_UPDATE
                elif c_fileinfo.fileid.int and not c_fileinfo.deleted:
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
                    Packets.RPL_SYNC,
                    None,
                    String(self._action),
                    String(c_fileinfo.fileid.bytes),
                    String(str(c_rel_path)),
                    String(c_fileinfo.modified.isoformat()),
                    Boolean(c_fileinfo.deleted),
                )
                logging.info("RPL_SYNC(%s) sent" % self._action)

                confirm, _ = await self.handle_packet({
                    Packets.RPL_CONFIRM: self._process_confirm
                })

                if not confirm:
                    raise Error(
                       reason='File sync action not confirmed by server.',
                       code=1)

                self._serverfile = s_fileinfo
                self._clientfile = c_fileinfo

                if self._action == Actions.CLI_CREATE:
                    self._clientfile.fileid = self._serverfile.fileid
                    self._clientfile.path = self._serverfile.path
                    await self.download()
                elif self._action == Actions.CLI_UPDATE:
                    await self.download()
                elif self._action == Actions.SER_UPDATE:
                    await self.upload()
                elif self._action == Actions.CLI_DELETE:
                    await self.delete()
                else:
                    raise Error(
                        reason="Unkown action '%s'" % self._action,
                        code=1)

                crash = False
            except Exception as e:
                logging.error(e, exc_info=True)
                if not self._aborted:
                    self.send_packet(Packets.RPL_ABORT, None)
                    logging.info("RPL_ABORT sent")
                else:
                    self._aborted = False
                if isinstance(e, Error):
                    logging.warning(e)
                elif isinstance(e, AngelosException):
                    logging.exception(e, exc_info=True)
                else:
                    raise e
                crash = True
            finally:
                if self._clientfile:
                    self.client.preset.file_processed(self._clientfile.fileid)
                await self.client.preset.on_after_pull(
                    self._serverfile, self._clientfile, self.client.ioc, crash)
                self._serverfile = None
                self._clientfile = None
                self._action = None
                if self._counter.limit():
                    raise Error(reason="Max abort threshold reached", code=1)

    async def push(self):
        """Synchronize using push to the server."""
        while True:
            try:
                await self.client.preset.on_before_push(self.client.ioc)
                # Load file metadata
                c_fileinfo = self.client.preset.pull_file_meta()
                if not c_fileinfo.fileid.int:
                    break
                self._clientfile = c_fileinfo
                c_rel_path = self.client.preset.to_relative(
                    self._clientfile.path)

                self.send_packet(
                    Packets.RPL_REQUEST,
                    None,
                    String("push"),
                    String(c_fileinfo.fileid.bytes),
                    String(str(c_rel_path)),
                    String(c_fileinfo.modified.isoformat()),
                    Boolean(c_fileinfo.deleted),
                )
                logging.info("RPL_REQUEST(push) sent")

                s_fileinfo, pkttype = await self.handle_packet({
                    Packets.RPL_RESPONSE: self._process_response
                })

                # Calculate what action to take based on client and server
                # file circumstances.
                if not s_fileinfo.fileid.int:
                    if c_fileinfo.deleted:
                        self._action = Actions.NO_ACTION
                    else:
                        self._action = Actions.SER_CREATE
                elif s_fileinfo.fileid.int and s_fileinfo.deleted:
                    if c_fileinfo.deleted:
                        self._action = Actions.NO_ACTION
                    else:
                        if s_fileinfo.modified > c_fileinfo.modified:
                            self._action = Actions.CLI_DELETE
                        else:
                            self._action = Actions.SER_UPDATE
                elif s_fileinfo.fileid.int and not s_fileinfo.deleted:
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

                self.send_packet(Packets.RPL_SYNC, None, String(self._action))
                logging.info("RPL_SYNC(%s) sent" % self._action)

                confirm, _ = await self.handle_packet({
                    Packets.RPL_CONFIRM: self._process_confirm
                })

                if not confirm:
                    raise Error(
                       reason='File sync action not confirmed by server.',
                       code=1)

                self._serverfile = s_fileinfo
                self._clientfile = c_fileinfo

                if self._action == Actions.SER_CREATE:
                    await self.upload()
                elif self._action == Actions.SER_UPDATE:
                    await self.upload()
                elif self._action == Actions.CLI_UPDATE:
                    await self.download()
                elif self._action == Actions.CLI_DELETE:
                    await self.delete()
                else:
                    raise Error(
                        reason="Unkown action '%s'" % self._action,
                        code=1)

                crash = False
            except Exception as e:
                logging.error(e, exc_info=True)
                if not self._aborted:
                    self.send_packet(Packets.RPL_ABORT, None)
                    logging.info("RPL_ABORT sent")
                else:
                    self._aborted = False
                if isinstance(e, Error):
                    logging.warning(e)
                elif isinstance(e, AngelosException):
                    logging.exception(e, exc_info=True)
                else:
                    raise e
                crash = True
            finally:
                if self._clientfile:
                    self.client.preset.file_processed(self._clientfile.fileid)
                await self.client.preset.on_after_push(
                    self._serverfile, self._clientfile, self.client.ioc, crash)
                self._serverfile = None
                self._clientfile = None
                self._action = None
                if self._counter.limit():
                    raise Error(reason="Max abort threshold reached", code=1)

    async def download(self) -> bool:
        try:
            await self.client.preset.on_before_download(
                self._serverfile, self._clientfile, self.client.ioc)
            self.send_packet(
                Packets.RPL_DOWNLOAD,
                None,
                String(self._serverfile.fileid.bytes),
                String(self._serverfile.path),
            )
            logging.info("RPL_DOWNLOAD(%s) sent" % self._serverfile.path)

            confirm, _ = await self.handle_packet({
                Packets.RPL_CONFIRM: self._process_confirm
            })

            if not confirm:
                raise Error(
                    reason="Server can not confirm download", code=1)

            self._chunk = "meta"
            self.send_packet(
                Packets.RPL_GET, None, String(self._chunk))
            logging.info("RPL_GET(meta) sent")

            await self.handle_packet({Packets.RPL_CHUNK: self._process_chunk})

            data = b""
            for piece in range(self._serverfile.pieces):
                self._chunk = "data"
                self.send_packet(
                    Packets.RPL_GET, None, String(self._chunk), UInt32(piece)
                )
                logging.info("RPL_GET(data, %s) sent" % piece)
                (rpiece, data), _ = await self.handle_packet({
                    Packets.RPL_CHUNK: self._process_chunk
                })
                if rpiece != piece:
                    raise Error(reason="Received wrong piece of data", code=1)
                self._serverfile.data += data

            data = self._serverfile.data
            if not len(data) == self._serverfile.size:
                raise Error(reason='File size mismatch', code=1)

            await self.client.ioc.facade.api.replication.save_file(
                self.client.preset, self._serverfile, self._action
            )

            self.send_packet(Packets.RPL_DONE, None)
            logging.info("RPL_DONE sent")

            await self.client.preset.on_after_download(
                self._serverfile, self._clientfile, self.client.ioc)
        except Exception as e:
            logging.error(e, exc_info=True)
            # logging.exception("Download error")
            await self.client.preset.on_after_download(
                self._serverfile, self._clientfile, self.client.ioc, True)
            raise

    async def upload(self) -> bool:
        try:
            # Load file from archive7
            await self.client.preset.on_before_upload(
                self._serverfile, self._clientfile, self.client.ioc)
            await self.client.ioc.facade.api.replication.load_file(
                self.client.preset, self._clientfile
            )
            c_rel_path = self.client.preset.to_relative(self._clientfile.path)

            self.send_packet(
                Packets.RPL_UPLOAD,
                None,
                String(self._clientfile.fileid.bytes),
                String(str(c_rel_path)),
                UInt32(self._clientfile.size),
            )
            logging.info("RPL_UPLOAD(%s) sent" % c_rel_path)

            confirm, _ = await self.handle_packet({
                Packets.RPL_CONFIRM: self._process_confirm
            })

            if not confirm:
                raise Error(reason="Server can not confirm upload", code=1)

            self._chunk = "meta"
            self.send_packet(
                Packets.RPL_PUT,
                None,
                String(self._chunk),
                UInt32(self._clientfile.pieces),
                String(self._clientfile.filename),
                String(self._clientfile.created.isoformat()),
                String(self._clientfile.modified.isoformat()),
                String(self._clientfile.owner.bytes),
                String(self._serverfile.fileid.bytes if self._serverfile.fileid.int else self._clientfile.fileid.bytes),
                String(self._clientfile.user),
                String(self._clientfile.group),
                UInt32(self._clientfile.perms)
            )
            logging.info("RPL_PUT(meta) sent")

            await self.handle_packet({
                Packets.RPL_RECEIVED: self._process_received})

            for piece in range(self._clientfile.pieces):
                offset = piece * CHUNK_SIZE
                self._chunk = "data"
                self.send_packet(
                    Packets.RPL_PUT,
                    None,
                    String(self._chunk),
                    UInt32(piece),
                    String(self._clientfile.data[offset:offset + CHUNK_SIZE]),
                )
                logging.info("RPL_PUT(data) sent")
                rpiece, _ = await self.handle_packet({
                    Packets.RPL_RECEIVED: self._process_received})
                if rpiece != piece:
                    raise Error(reason="Received wrong piece of data", code=1)

            self.send_packet(Packets.RPL_DONE, None)
            logging.info("RPL_DONE sent")
            await self.client.preset.on_after_upload(
                self._serverfile, self._clientfile, self.client.ioc)
        except Exception as e:
            logging.error(e, exc_info=True)
            # logging.exception("Upload error")
            await self.client.preset.on_after_upload(
                self._serverfile, self._clientfile, self.client.ioc, True)
            raise

    async def delete(self) -> bool:
        try:
            await self.client.preset.on_before_delete(
                self._serverfile, self._clientfile, self.client.ioc)
            # Delete file from Archive7
            await self.client.ioc.facade.api.replication.del_file(
                self.client.preset, self._clientfile
            )
            await self.client.preset.on_after_delete(
                self._serverfile, self._clientfile, self.client.ioc)
        except Exception as e:
            logging.error(e, exc_info=True)
            # logging.exception("Delete error")
            await self.client.preset.on_after_delete(
                self._serverfile, self._clientfile, self.client.ioc, True)
            raise

    async def _process_version(self, packet: SSHPacket):
        """
        Process the server returned version and ask for carrying out an
        operation.
        """
        version = packet.get_uint32()
        logging.info("RPL_VERSION(%s) received" % version)
        if version != VERSION:
            raise Error(reason="Unsupported version: %d" % version, code=1)

        packet.check_end()
        preset = self.client.preset

        if preset.preset != "custom":
            self.send_packet(
                Packets.RPL_OPERATION,
                None,
                UInt32(VERSION),
                String(preset.modified.isoformat()),
                String(preset.preset),
            )
            logging.info(
                "RPL_OPERATION(%s, %s) sent" % (preset.preset, VERSION)
            )
        else:
            self.send_packet(
                Packets.RPL_OPERATION,
                None,
                UInt32(VERSION),
                String(preset.modified.isoformat()),
                String(preset.preset),
                String(preset.archive),
                String(preset.path),
                String(preset.owner.bytes),
            )
            logging.info(
                "RPL_OPERATION(%s, %s) sent" % (preset, VERSION)
            )

    async def _process_confirm(self, packet: SSHPacket) -> bool:
        """Process the server confirmation."""
        confirmation = packet.get_boolean()
        logging.info("RPL_CONFIRM(%s) received" % confirmation)
        packet.check_end()

        return confirmation

    async def _process_response(self, packet: SSHPacket) -> FileSyncInfo:
        """Process response from request and return file information."""
        fileinfo = FileSyncInfo()
        fileinfo.fileid = uuid.UUID(bytes=packet.get_string())
        fileinfo.path = packet.get_string().decode()
        fileinfo.modified = datetime.datetime.fromisoformat(
            packet.get_string().decode()
        )
        fileinfo.deleted = packet.get_boolean()
        packet.check_end()
        logging.info("RPL_RESPONSE(%s) received" % fileinfo.path)

        return fileinfo

    async def _process_chunk(self, packet: SSHPacket):
        meta = packet.get_string().decode()
        if meta != self._chunk:
            raise Error(reason="Wrong chunk type", code=1)
        if meta == "meta":
            self._serverfile.pieces = packet.get_uint32()
            self._serverfile.size = packet.get_uint32()

            self._serverfile.filename = packet.get_string().decode()
            self._serverfile.created = datetime.datetime.fromisoformat(
                packet.get_string().decode()
            )
            self._serverfile.modified = datetime.datetime.fromisoformat(
                packet.get_string().decode()
            )
            self._serverfile.owner = uuid.UUID(bytes=packet.get_string())
            self._serverfile.fileid = uuid.UUID(bytes=packet.get_string())
            self._serverfile.user = packet.get_string().decode()
            self._serverfile.group = packet.get_string().decode()
            self._serverfile.perms = packet.get_uint32()

            packet.check_end()
            logging.info("RPL_CHUNK(meta) received")
            return self._serverfile
        if meta == "data":
            piece = packet.get_uint32()
            data = packet.get_string()

            packet.check_end()
            logging.info("RPL_CHUNK(data, %s) received" % piece)
            return piece, data
        else:
            Error(
                reason="RPL_CHUNK expects meta or data. %s given." % meta,
                code=1
            )

    async def _process_received(self, packet: SSHPacket):
        meta = packet.get_string().decode()
        if meta != self._chunk:
            raise Error(reason="Wrong chunk type", code=1)
        if meta == "meta":
            packet.check_end()
            logging.info("RPL_RECEIVED(meta) received")
            return True
        elif meta == "data":
            piece = packet.get_uint32()
            packet.check_end()
            logging.info("RPL_RECEIVED(data, %s) received" % piece)
            return piece
        else:
            raise Error(reason="RPL_RECEIVED illegal, meta or data", code=1)

    async def _process_abort(self, packet: SSHPacket):
        pass

    async def _process_done(self, packet: SSHPacket):
        logging.info("RPL_DONE received")

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

    async def run(self):
        """Replication server handler entry-point."""
        try:
            self._server.logger.info("Starting Replicator server")
            # Wait for RPL_INIT
            version, _ = await self.handle_packet({
                Packets.RPL_INIT: self._process_init
            })

            self.send_packet(Packets.RPL_VERSION, None, UInt32(VERSION))
            logging.info("RPL_VERSION(%s) sent" % VERSION)

            # Wait for RPL_OPERATION
            negotiated, _ = await self.handle_packet({
                Packets.RPL_OPERATION: self._process_operation
            })
            await self._preset.on_init(self._server.ioc, self._server.portfolio)

            # Check protocol versions and presets of custom circumstances.
            confirm = negotiated == version
            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(confirm))
            logging.info("RPL_CONFIRM(%s) sent" % confirm)

            if negotiated != version:
                raise Error(reason="Incompatible protocol version", code=1)

            # Loop for receiving pull/push
            await self._server.ioc.facade.api.replication.load_files_list(self._preset)

            while True:
                _, pkttype = await self.handle_packet({
                    Packets.RPL_REQUEST: self._process_request,
                    Packets.RPL_CLOSE: self._process_close
                })

                if pkttype == Packets.RPL_CLOSE:
                    break
            await self._preset.on_close(self._server.ioc, self._server.portfolio)

        except (asyncio.IncompleteReadError, PacketDecodeError, Error) as e:
            logging.error(e, exc_info=True)
            # logging.exception("Network error")
            raise

    async def _process_init(self, packet):
        version = packet.get_uint32()
        packet.check_end()
        logging.info("RPL_INIT(%s) received" % version)
        return version

    async def _process_operation(self, packet):
        version = packet.get_uint32()
        modified = datetime.datetime.fromisoformat(
            packet.get_string().decode()
        )
        preset_type = packet.get_string().decode()

        if preset_type == "custom":
            archive = packet.get_string().decode()
            path = packet.get_string().decode()
            owner = uuid.UUID(bytes=packet.get_string())
            self._preset = self._server.ioc.facade.api.replication.create_preset(
                preset_type,
                Preset.SERVER,
                self._server.portfolio.entity.id,
                modified=modified,
                archive=archive,
                path=path,
                owner=owner,
            )
        else:
            self._preset = self._server.ioc.facade.api.replication.create_preset(
                preset_type,
                Preset.SERVER,
                self._server.portfolio.entity.id,
                modified=modified,
            )

        logging.info("RPL_OPERATION(%s) received" % version)
        packet.check_end()
        return version

    async def _process_request(self, packet):
        _type = packet.get_string().decode()

        if _type == "pull":
            packet.check_end()
            logging.info("RPL_REQUEST(pull) received")
            await self.pulled()
        elif _type == "push":
            c_fileinfo = FileSyncInfo()
            c_fileinfo.fileid = uuid.UUID(bytes=packet.get_string())
            c_fileinfo.path = packet.get_string().decode()
            c_fileinfo.modified = datetime.datetime.fromisoformat(
                packet.get_string().decode()
            )
            c_fileinfo.deleted = packet.get_boolean()
            packet.check_end()
            logging.info("RPL_REQUEST(push, %s) received" % c_fileinfo.path)
            await self.pushed(c_fileinfo)
        else:
            raise Error(
                reaseon="Unknown command %s, expected pull or push." % _type,
                code=1,
            )

    async def _process_sync(self, packet):
        action = packet.get_string().decode()
        fileinfo = FileSyncInfo()

        if packet:
            fileinfo.fileid = uuid.UUID(bytes=packet.get_string())
            fileinfo.path = packet.get_string().decode()
            fileinfo.modified = datetime.datetime.fromisoformat(
                packet.get_string().decode()
            )
            fileinfo.deleted = packet.get_boolean()
            packet.check_end()
            logging.info("RPL_SYNC(%s, %s) received" % (action, fileinfo.path))
        else:
            packet.check_end()
            logging.info("RPL_SYNC(%s) received" % action)

        return action, fileinfo

    async def _process_download(self, packet):
        self._clientfile.fileid = uuid.UUID(bytes=packet.get_string())
        self._clientfile.path = packet.get_string().decode()
        packet.check_end()
        logging.info("RPL_DOWNLOAD(%s) received" % self._clientfile.path)

    async def _process_get(self, packet):
        _type = packet.get_string().decode()

        if _type == "meta":
            packet.check_end()
            logging.info("RPL_GET(%s) received" % (_type))
            # Get meta from loaded file
            self._serverfile.pieces = math.ceil(
                self._serverfile.size / CHUNK_SIZE)
            self.send_packet(
                Packets.RPL_CHUNK,
                None,
                String("meta"),
                UInt32(self._serverfile.pieces),
                UInt32(self._serverfile.size),
                String(self._serverfile.filename),
                String(self._serverfile.created.isoformat()),
                String(self._serverfile.modified.isoformat()),
                String(self._serverfile.owner.bytes),
                String(self._serverfile.fileid.bytes),
                String(self._serverfile.user),
                String(self._serverfile.group),
                UInt32(self._serverfile.perms)
            )
            logging.info("RPL_CHUNK(meta) sent")

        elif _type == "data":
            piece = packet.get_uint32()
            packet.check_end()
            logging.info("RPL_GET(%s, %s) received" % (_type, piece))
            # Get data from loaded file
            data = self._serverfile.data[piece*CHUNK_SIZE:min(
                (piece+1)*CHUNK_SIZE, len(self._serverfile.data))]
            self.send_packet(
                Packets.RPL_CHUNK,
                None,
                String("data"),
                UInt32(piece),
                String(data),
            )
            logging.info("RPL_CHUNK(data, %s) sent" % piece)
        else:
            raise Error(reason="Illegal get type.", code=1)

    async def _process_upload(self, packet):
        fileid = uuid.UUID(bytes=packet.get_string())
        path = packet.get_string().decode()
        size = packet.get_uint32()
        packet.check_end()
        logging.info("RPL_UPLOAD(%s) received" % path)

        if self._clientfile.fileid != fileid or self._clientfile.path != path:
            raise Error(reason="File ID or path not consequent.")

        self._clientfile.fileid = fileid
        self._clientfile.path = path
        self._clientfile.size = size

    async def _process_put(self, packet):
        _type = packet.get_string().decode()
        if _type == "meta":
            # Get meta from loaded file
            self._clientfile.pieces = packet.get_uint32()

            self._clientfile.filename = packet.get_string().decode()
            self._clientfile.created = datetime.datetime.fromisoformat(
                packet.get_string().decode()
            )
            self._clientfile.modified = datetime.datetime.fromisoformat(
                packet.get_string().decode()
            )
            self._clientfile.owner = uuid.UUID(bytes=packet.get_string())
            self._clientfile.fileid = uuid.UUID(bytes=packet.get_string())
            self._clientfile.user = packet.get_string().decode()
            self._clientfile.group = packet.get_string().decode()
            self._clientfile.perms = packet.get_uint32()

            packet.check_end()
            logging.info("RPL_PUT(meta) received")
            # Store meta data
            self.send_packet(
                Packets.RPL_RECEIVED,
                None,
                String("meta")
            )
            logging.info("RPL_RECEIVED(meta) sent")
            return self._clientfile
        elif _type == "data":
            # Get data from loaded file
            piece = packet.get_uint32()
            data = packet.get_string()
            packet.check_end()
            logging.info("RPL_PUT(data, %s) received" % piece)
            # Save data to file
            self.send_packet(
                Packets.RPL_RECEIVED, None, String("data"), UInt32(piece)
            )
            logging.info("RPL_RECEIVED(data, %s) sent" % piece)
            return piece, data
        else:
            raise Error(reason="Illegal put type.", code=1)

    async def _process_done(self, packet):
        logging.info("RPL_DONE received")

    async def _process_close(self, packet):
        logging.info("RPL_CLOSE received")
        self._server.connection.close()

    async def pulled(self):
        try:
            await self._preset.on_before_pull(
                self._server.ioc, self._server.portfolio)
            # Load a file from archive7 to be pulled
            s_fileinfo = self._preset.pull_file_meta()

            if s_fileinfo.fileid.int:
                await self._server.ioc.facade.api.replication.load_file(
                    self._preset, s_fileinfo)

                if s_fileinfo.path:
                    s_rel_path = self._preset.to_relative(s_fileinfo.path)
                else:
                    s_rel_path = s_fileinfo.path
                self.send_packet(
                    Packets.RPL_RESPONSE,
                    None,
                    String(s_fileinfo.fileid.bytes),
                    String(str(s_rel_path)),
                    String(s_fileinfo.modified.isoformat()),
                    Boolean(s_fileinfo.deleted),
                )
                logging.info("RPL_RESPONSE(%s) sent" % s_rel_path)
            else:
                self.send_packet(Packets.RPL_DONE, None)
                logging.info("RPL_DONE sent")
                return

            (action, c_fileinfo), _ = await self.handle_packet({
                Packets.RPL_SYNC: self._process_sync
            })

            # Calculate what action to take based on client and server
            # file circumstances.
            if not c_fileinfo.fileid.int:
                if s_fileinfo.deleted:
                    self._action = Actions.NO_ACTION
                else:
                    self._action = Actions.CLI_CREATE
            elif c_fileinfo.fileid.int and c_fileinfo.deleted:
                if s_fileinfo.deleted:
                    self._action = Actions.NO_ACTION
                else:
                    if c_fileinfo.modified > s_fileinfo.modified:
                        self._action = Actions.SER_DELETE
                    else:
                        self._action = Actions.CLI_UPDATE
            elif c_fileinfo.fileid.int and not c_fileinfo.deleted:
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
                logging.info("RPL_CONFIRM(%s) sent" % True)
                self._serverfile = s_fileinfo
                self._clientfile = c_fileinfo
            else:
                self.send_packet(Packets.RPL_CONFIRM, None, Boolean(False))
                logging.info("RPL_CONFIRM(%s) sent" % False)
                self._serverfile = None
                self._clientfile = None
                self._action = None
                return

            if self._action == Actions.SER_UPDATE:
                await self.uploading()
            elif self._action == Actions.CLI_CREATE:
                await self.downloading()
            elif self._action == Actions.CLI_UPDATE:
                await self.downloading()
            elif self._action == Actions.SER_DELETE:
                await self.delete()
            else:
                raise Error(
                    reason="Unkown action '%s'" % self._action,
                    code=1)

            crash = False
        except Exception as e:
            logging.error(e, exc_info=True)
            if not self._aborted:
                self.send_packet(Packets.RPL_ABORT, None)
                logging.info("RPL_ABORT sent")
            else:
                self._aborted = False
            if isinstance(e, Error):
                logging.warning(e)
            elif isinstance(e, AngelosException):
                logging.exception(e, exc_info=True)
            else:
                raise e
            crash = True
        finally:
            if self._clientfile:
                self._preset.file_processed(self._clientfile.fileid)
            await self._preset.on_after_pull(
                self._serverfile, self._clientfile, self._server.ioc,
                self._server.portfolio, crash)
            self._serverfile = None
            self._clientfile = None
            self._action = None
            if self._counter.limit():
                raise Error(reason="Max abort threshold reached", code=1)

    async def pushed(self, c_fileinfo: FileSyncInfo):
        try:
            await self._preset.on_before_push(
                self._server.ioc, self._server.portfolio)
            # Load a file from archive7 to be pulled
            s_fileinfo = self._preset.get_file_meta(c_fileinfo.fileid)

            self.send_packet(
                Packets.RPL_RESPONSE,
                None,
                String(s_fileinfo.fileid.bytes),
                String(str(s_fileinfo.path)),
                String(s_fileinfo.modified.isoformat()),
                Boolean(s_fileinfo.deleted),
            )
            logging.info("RPL_RESPONSE(%s) sent" % (
                s_fileinfo.path if s_fileinfo.fileid.int else (
                    c_fileinfo.path)))

            (action, _), _ = await self.handle_packet({
                Packets.RPL_SYNC: self._process_sync
            })

            # Calculate what action to take based on client and server
            # file circumstances.
            if not s_fileinfo.fileid.int:
                if c_fileinfo.deleted:
                    self._action = Actions.NO_ACTION
                else:
                    self._action = Actions.SER_CREATE
            elif s_fileinfo.fileid.int and s_fileinfo.deleted:
                if c_fileinfo.deleted:
                    self._action = Actions.NO_ACTION
                else:
                    if s_fileinfo.modified > c_fileinfo.modified:
                        self._action = Actions.CLI_DELETE
                    else:
                        self._action = Actions.SER_UPDATE
            elif s_fileinfo.fileid.int and not s_fileinfo.deleted:
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
                logging.info("RPL_CONFIRM(%s) sent" % True)
                self._serverfile = s_fileinfo
                self._clientfile = c_fileinfo
            else:
                self.send_packet(Packets.RPL_CONFIRM, None, Boolean(False))
                logging.info("RPL_CONFIRM(%s) sent" % False)
                self._serverfile = None
                self._clientfile = None
                self._action = None
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
                raise Error(reason="Unkown action '%s'" % self._action, code=1)

            crash = False
        except Exception as e:
            logging.error(e, exc_info=True)
            if not self._aborted:
                self.send_packet(Packets.RPL_ABORT, None)
                logging.info("RPL_ABORT sent")
            else:
                self._aborted = False
            if isinstance(e, Error):
                logging.warning(e)
            elif isinstance(e, AngelosException):
                logging.exception(e, exc_info=True)
            else:
                raise e
            crash = True
        finally:
            if self._clientfile:
                self._preset.file_processed(self._clientfile.fileid)
            await self._preset.on_after_push(
                self._serverfile, self._clientfile, self._server.ioc,
                self._server.portfolio, crash)
            self._serverfile = None
            self._clientfile = None
            self._action = None
            if self._counter.limit():
                raise Error(reason="Max abort threshold reached", code=1)

    async def downloading(self):
        try:
            await self._preset.on_before_download(
                self._serverfile, self._clientfile, self._server.ioc,
                self._server.portfolio)
            await self.handle_packet({
                Packets.RPL_DOWNLOAD: self._process_download
            })
            s_rel_path = self._preset.to_relative(self._serverfile.path)

            if self._clientfile.fileid.int == self._serverfile.fileid.int and (
                self._clientfile.path == s_rel_path
            ):
                self.send_packet(Packets.RPL_CONFIRM, None, Boolean(True))
                logging.info("RPL_CONFIRM(%s) sent" % True)
            else:
                self.send_packet(Packets.RPL_CONFIRM, None, Boolean(False))
                logging.info("RPL_CONFIRM(%s) sent" % False)
                return

            await self.handle_packet({
                Packets.RPL_GET: self._process_get
            })

            while True:
                _, pkttype = await self.handle_packet({
                    Packets.RPL_GET: self._process_get,
                    Packets.RPL_DONE: self._process_done
                })

                if pkttype == Packets.RPL_DONE:
                    break

            await self._preset.on_after_download(
                self._serverfile, self._clientfile, self._server.ioc,
                self._server.portfolio)
        except Exception as e:
            logging.error(e, exc_info=True)
            # logging.exception("Downloading error")
            await self._preset.on_after_download(
                self._serverfile, self._clientfile, self._server.ioc,
                self._server.portfolio, True)
            raise

    async def uploading(self):
        try:
            await self._preset.on_before_upload(
                self._serverfile, self._clientfile, self._server.ioc,
                self._server.portfolio)
            await self.handle_packet({
                Packets.RPL_UPLOAD: self._process_upload
            })

            self.send_packet(Packets.RPL_CONFIRM, None, Boolean(True))
            logging.info("RPL_CONFIRM(%s) sent" % True)

            await self.handle_packet({Packets.RPL_PUT: self._process_put})

            rpiece = 0
            while True:
                result, pkttype = await self.handle_packet({
                    Packets.RPL_PUT: self._process_put,
                    Packets.RPL_DONE: self._process_done
                })

                if pkttype == Packets.RPL_DONE:
                    break

                (piece, data) = result

                if rpiece != piece:
                    raise Error(reason="Received wrong piece of data", code=1)
                rpiece = piece + 1
                self._clientfile.data += data

            if not len(self._clientfile.data) == self._clientfile.size:
                raise Error(reason='File size mismatch', code=1)

            await self._server.ioc.facade.api.replication.save_file(
                self._preset, self._clientfile, self._action
            )

            await self._preset.on_after_upload(
                self._serverfile, self._clientfile, self._server.ioc,
                self._server.portfolio)
        except Exception as e:
            logging.error(e, exc_info=True)
            # logging.exception("Uploading error")
            await self._preset.on_after_upload(
                self._serverfile, self._clientfile, self._server.ioc,
                self._server.portfolio, True)
            raise

    async def delete(self) -> bool:
        try:
            await self._preset.on_before_delete(
                self._serverfile, self._clientfile, self._server.ioc)
            # Delete file from Archive7
            await self._server.ioc.facade.api.replication.del_file(
                self._preset, self._serverfile
            )
            await self.client.preset.on_after_delete(
                self._serverfile, self._clientfile, self._server.ioc)
        except Exception as e:
            logging.error(e, exc_info=True)
            # logging.exception("Delete error")
            await self._preset.on_after_delete(
                self._serverfile, self._clientfile, self._server.ioc, True)
            raise
