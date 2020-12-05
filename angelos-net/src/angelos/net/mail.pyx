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
from angelos.net.base import PacketHandler, TELL_PACKET, r, SHOW_PACKET, CONFIRM_PACKET, START_PACKET, FINISH_PACKET, \
    ACCEPT_PACKET, REFUSE_PACKET, BUSY_PACKET, DONE_PACKET, TellPacket, ShowPacket, \
    ConfirmPacket, StartPacket, FinishPacket, AcceptPacket, RefusePacket, BusyPacket, DonePacket, \
    ServerStateExchangeMachine, ClientStateExchangeMachine, ConfirmCode, GotoStateError


class MailError(RuntimeError):
    """Unrepairable errors in the mail handler."""
    pass


class MailHandler(PacketHandler):
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

    # SESH
    ST_ALL = 0x01

    def __init__(self, manager: "PacketManager", server: bool):
        super().__init__(manager)
        self._states = {
            self.ST_ALL: "1"
        }
        self._state_machines = {
            self.ST_ALL: ServerStateExchangeMachine() if server else ClientStateExchangeMachine()
        }

    async def process_tell(self, packet: TellPacket):
        """Process a state push."""
        try:
            machine = self._state_machines[packet.state].goto("confirm")
            if packet.value == "?":  # At unknown state we can safely raise KeyError
                raise KeyError()
            # TODO: Deal with state value
            self._states[packet.state] = packet.value
            self._manager.send_packet(
                self.PKT_CONFIRM, self.LEVEL, ConfirmPacket(
                    packet.state, ConfirmCode.YES, packet.type, packet.session))
        except KeyError:
            self._manager.send_packet(
                self.PKT_CONFIRM, self.LEVEL, ConfirmPacket(
                    packet.state, ConfirmCode.NO_COMMENT, packet.type, packet.session))
        finally:
            self._state_machines[packet.state].goto("done")

    async def process_show(self, packet: ShowPacket):
        """Process request to show state."""
        try:
            self._state_machines[packet.state].goto("show")
            state = self._states[packet.state]
        except KeyError:
            state = "?"
        finally:
            self._manager.send_packet(
                self.PKT_TELL, self.LEVEL, TellPacket(
                    packet.state, state, packet.type, packet.session))

    async def process_confirm(self, packet: ConfirmPacket):
        """Process a confirmation of state received and acceptance."""
        try:
            machine = self._state_machines[packet.proposal]
            machine.goto("confirm")
            # TODO: Deal with packet.answer ...
            machine.goto("done")
        except KeyError:
            if packet.answer != ConfirmCode.NO_COMMENT:
                raise
        except GotoStateError:
            raise

    async def process_start(self, packet: StartPacket):
        pass

    async def process_finish(self, packet: FinishPacket):
        pass

    async def process_accept(self, packet: AcceptPacket):
        pass

    async def process_refuse(self, packet: RefusePacket):
        pass

    async def process_busy(self, packet: BusyPacket):
        pass

    async def process_done(self, packet: DonePacket):
        pass


class MailClient(MailHandler):
    """Client side mail handler."""

    PROCESS = {
        MailHandler.PKT_TELL: None,
        MailHandler.PKT_SHOW: "process_show",
        MailHandler.PKT_CONFIRM: "process_confirm",
    }

    def __init__(self, manager: "PacketManager"):
        super().__init__(manager, False)

    def start(self):
        """Make authentication against server."""
        print("Start mail replication")

    async def tell_state(self, state: int, type: int = 0, session: int = 0):
        """Tell state for server."""
        self._state_machines[state].goto("tell")
        value = self._states[state]
        self._manager.send_packet(
            self.PKT_TELL, self.LEVEL, TellPacket(
                state, value, type, session))

class MailServer(MailHandler):
    """Server side mail handler."""

    PROCESS = {
        MailHandler.PKT_TELL: "process_tell",
        MailHandler.PKT_SHOW: None,
        MailHandler.PKT_CONFIRM: None,
    }

    def __init__(self, manager: "PacketManager"):
        super().__init__(manager, True)

    async def show_state(self, state: int, type: int = 0, session: int = 0):
        """Request to know state from client."""
        self._state_machines[state].goto("show")
        self._manager.send_packet(
            self.PKT_SHOW, self.LEVEL, ShowPacket(state, type, session))
