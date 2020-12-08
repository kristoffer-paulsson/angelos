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
"""Authentication handler."""
from angelos.net.base import TELL_PACKET, r, SHOW_PACKET, CONFIRM_PACKET, START_PACKET, FINISH_PACKET, \
    ACCEPT_PACKET, REFUSE_PACKET, BUSY_PACKET, DONE_PACKET, TellPacket, ShowPacket, \
    ConfirmPacket, StartPacket, FinishPacket, AcceptPacket, RefusePacket, BusyPacket, DonePacket, \
    ServerStateExchangeMachine, ClientStateExchangeMachine, ConfirmCode, GotoStateError, Handler, ProtocolSession, \
    SessionCode


class MailError(RuntimeError):
    """Unrepairable errors in the mail handler."""
    pass


class MailHandler(Handler):
    """Base handler for mail."""

    LEVEL = 1
    RANGE = 1

    R_START = r(RANGE)[0]

    PKT_TELL = TELL_PACKET + R_START  # Tell the state of things
    PKT_SHOW = SHOW_PACKET + R_START  # Demand to know the state if things
    PKT_CONFIRM = CONFIRM_PACKET + R_START  # Accept or deny a state change or proposal

    PKT_START = START_PACKET + R_START  # Initiate a session
    PKT_FINISH = FINISH_PACKET + R_START  # Finalize a started session
    PKT_ACCEPT = ACCEPT_PACKET + R_START  # Acceptance toward session or request
    PKT_REFUSE = REFUSE_PACKET + R_START  # Refusal of session or request
    PKT_BUSY = BUSY_PACKET + R_START  # To busy for session or request
    PKT_DONE = DONE_PACKET + R_START  # Nothing more to do in session or request

    PACKETS = {
        PKT_TELL: TellPacket,
        PKT_SHOW: ShowPacket,
        PKT_CONFIRM: ConfirmPacket,
        PKT_START: StartPacket,
        PKT_FINISH: FinishPacket,
        PKT_ACCEPT: AcceptPacket,
        PKT_REFUSE: RefusePacket,
        PKT_BUSY: BusyPacket,
        PKT_DONE: DonePacket
    }

    PROCESS = dict()

    SESH_ALL = 0x01
    ST_ALL = 0x01

    def __init__(self, manager: "Protocol"):
        super().__init__(manager)
        server = manager.is_server()
        self._states = {
            self.ST_ALL: b"1"
        }
        self._state_machines = {
            self.ST_ALL: ServerStateExchangeMachine() if server else ClientStateExchangeMachine()
        }
        self._sessions = dict()
        self._session_types = {self.SESH_ALL: ProtocolSession}
        self._max_sessions = 8
        self._session_count = 0

    def get_session(self, session: int) -> ProtocolSession:
        if session in self._sessions.keys():
            return self._sessions[session]
        else:
            return None

    async def process_tell(self, packet: TellPacket):
        """Process a state push."""
        try:
            machine = self._state_machines[packet.state]
            machine.goto("tell")

            if packet.value == b"?" or not callable(machine.check):
                result = ConfirmCode.NO_COMMENT
            else:
                machine.value = packet.value
                result = machine.evaluate()

                if result == ConfirmCode.YES:
                    self._states[packet.state] = packet.value

                if machine.condition.locked():
                    machine.condition.notify_all()

            machine.goto("accomplished")
        except KeyError:
            result = ConfirmCode.NO_COMMENT
        finally:
            self._manager.send_packet(
                self.PKT_CONFIRM, self.LEVEL, ConfirmPacket(
                    packet.state, result, packet.type, packet.session))

    async def process_show(self, packet: ShowPacket):
        """Process request to show state."""
        try:
            self._state_machines[packet.state].goto("show")
            state = self._states[packet.state]
        except KeyError:
            state = b"?"
        finally:
            self._manager.send_packet(
                self.PKT_TELL, self.LEVEL, TellPacket(
                    packet.state, state, packet.type, packet.session))

    async def process_confirm(self, packet: ConfirmPacket):
        """Process a confirmation of state received and acceptance."""
        try:
            machine = self._state_machines[packet.proposal]
            machine.goto("confirm")
            machine.answer = packet.answer
            machine.event.set()
            machine.goto("accomplished")
        except KeyError:
            if packet.answer != ConfirmCode.NO_COMMENT:
                raise
        except GotoStateError:
            raise

    async def process_start(self, packet: StartPacket):
        """Session start requested."""
        if len(self._sessions) >= self._max_sessions:
            self._manager.send_packet(self.PKT_BUSY, self.LEVEL, BusyPacket(packet.type, packet.session))
        elif packet.session in self._sessions.keys() or packet.type not in self._session_types.keys():
            self._manager.send_packet(self.PKT_REFUSE, self.LEVEL, RefusePacket(packet.type, packet.session))
        else:
            session = await self._create_session(packet.type, packet.session)
            if not session:
                self._manager.send_packet(self.PKT_REFUSE, self.LEVEL, RefusePacket(packet.type, packet.session))
            else:
                session.own.goto("start")
                self._manager.send_packet(self.PKT_ACCEPT, self.LEVEL, AcceptPacket(packet.type, packet.session))

    async def process_finish(self, packet: FinishPacket):
        session = self._sessions[packet.session]
        if session.type != packet.type:
            raise TypeError()

        session.own.goto("finish")
        session.own.goto("accomplished")
        del self._sessions[packet.session]

    async def process_accept(self, packet: AcceptPacket):
        session = self._sessions[packet.session]
        if session.type != packet.type:
            raise TypeError()

        session.own.goto("accept")
        session.own.future.set_result(SessionCode.ACCEPT)

    async def process_refuse(self, packet: RefusePacket):
        session = self._sessions[packet.session]
        if session.type != packet.type:
            raise TypeError()

        session.own.goto("refuse")
        session.own.goto("accomplished")
        session.own.future.set_result(SessionCode.REFUSE)
        del self._sessions[packet.session]

    async def process_busy(self, packet: BusyPacket):
        session = self._sessions[packet.session]
        if session.type != packet.type:
            raise TypeError()

        session.own.goto("busy")
        session.own.goto("accomplished")
        session.own.future.set_result(SessionCode.BUSY)
        del self._sessions[packet.session]

    async def process_done(self, packet: DonePacket):
        session = self._sessions[packet.session]
        if session.type != packet.type:
            raise TypeError()

        session.own.event.set()
        session.own.goto("done")


class MailClient(MailHandler):
    """Client side mail handler."""

    PROCESS = {
        MailHandler.PKT_TELL: None,
        MailHandler.PKT_SHOW: "process_show",
        MailHandler.PKT_CONFIRM: "process_confirm",

        MailHandler.PKT_START: None,
        MailHandler.PKT_REFUSE: "process_refuse",
        MailHandler.PKT_BUSY: "process_busy",
        MailHandler.PKT_ACCEPT: "process_accept",
        MailHandler.PKT_FINISH: None,
        MailHandler.PKT_DONE: "process_done",
    }

    def start(self):
        """Make authentication against server."""
        print("Start mail replication")

    async def open_session(self, type: int) -> int:
        """Open a new session of certain type."""
        self._session_count += 1
        session = self._session_count

        sesh = ProtocolSession(type, dict(), self._manager.is_server())
        self._sessions[session] = sesh

        sesh.own.goto("start")
        self._manager.send_packet(self.PKT_START, self.LEVEL, StartPacket(type, session))
        await sesh.own.future
        return self._session_count if sesh.own.future.result() == SessionCode.ACCEPT else None

    async def stop_session(self, type: int, session: int):
        """Stop a running session and clean up."""
        sesh = self._sessions[session]
        if sesh.type != type:
            raise TypeError()

        sesh.own.goto("finish")
        self._manager.send_packet(self.PKT_FINISH, self.LEVEL, FinishPacket(type, session))

        sesh.own.goto("accomplished")
        del self._sessions[session]

    async def tell_state(self, state: int, type: int = 0, session: int = 0) -> int:
        """Tell certain state to server and give response"""
        machine = self._state_machines[state]
        machine.event.clear()
        machine.goto("tell")
        self._manager.send_packet(
            self.PKT_TELL, self.LEVEL, TellPacket(
                state, self._states[state], type, session))
        await machine.event.wait()
        return machine.answer


class MailServer(MailHandler):
    """Server side mail handler."""

    PROCESS = {
        MailHandler.PKT_TELL: "process_tell",
        MailHandler.PKT_SHOW: None,
        MailHandler.PKT_CONFIRM: None,

        MailHandler.PKT_START: "process_start",
        MailHandler.PKT_REFUSE: None,
        MailHandler.PKT_BUSY: None,
        MailHandler.PKT_ACCEPT: None,
        MailHandler.PKT_FINISH: "process_finish",
        MailHandler.PKT_DONE: None,
    }

    async def _create_session(self, type: int = 0, session: int = 0) -> ProtocolSession:
        """Create a new session based on request from client"""
        sesh = self._session_types[type](type, dict(), self._manager.is_server())
        self._sessions[session] = sesh
        return sesh

    async def session_done(self, type: int, session: int):
        """Tell client there is no more to do in session."""
        sesh = self._sessions[session]
        if sesh.type != type:
            raise TypeError()

        sesh.own.goto("done")
        self._manager.send_packet(self.PKT_DONE, self.LEVEL, DonePacket(type, session))

    async def show_state(self, state: int, type: int = 0, session: int = 0):
        """Request to know state from client."""
        self._state_machines[state].goto("show")
        self._manager.send_packet(self.PKT_SHOW, self.LEVEL, ShowPacket(state, type, session))
