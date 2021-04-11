import asyncio
import copy
import os
import re
import select
import signal
import sys
import termios
import tty
import unicodedata
from argparse import ArgumentParser

"""Editing widget using the interior of a window object.
 Supports the following Emacs-like key bindings:
Ctrl-A      Go to left edge of window.
Ctrl-B      Cursor left, wrapping to previous line if appropriate.
Ctrl-D      Delete character under cursor.
Ctrl-E      Go to right edge (stripspaces off) or end of line (stripspaces on).
Ctrl-F      Cursor right, wrapping to next line when appropriate.
Ctrl-G      Terminate, returning the window contents.
Ctrl-H      Delete character backward.
Ctrl-J      Terminate if the window is 1 line, otherwise insert newline.
Ctrl-K      If line is blank, delete it, otherwise clear to end of line.
Ctrl-L      Refresh screen.
Ctrl-N      Cursor down; move down one line.
Ctrl-O      Insert a blank line at cursor location.
Ctrl-P      Cursor up; move up one line.
Move operations do nothing if the cursor is at an edge where the movement
is not possible.  The following synonyms are supported where possible:
KEY_LEFT = Ctrl-B, KEY_RIGHT = Ctrl-F, KEY_UP = Ctrl-P, KEY_DOWN = Ctrl-N
KEY_BACKSPACE = Ctrl-h
"""

NUL = 0x00  # ^@
SOH = 0x01  # ^A
STX = 0x02  # ^B
ETX = 0x03  # ^C
EOT = 0x04  # ^D
ENQ = 0x05  # ^E
ACK = 0x06  # ^F
BEL = 0x07  # ^G
BS = 0x08  # ^H
TAB = 0x09  # ^I
HT = 0x09  # ^I
LF = 0x0a  # ^J
NL = 0x0a  # ^J
VT = 0x0b  # ^K
FF = 0x0c  # ^L
CR = 0x0d  # ^M
SO = 0x0e  # ^N
SI = 0x0f  # ^O
DLE = 0x10  # ^P
DC1 = 0x11  # ^Q
DC2 = 0x12  # ^R
DC3 = 0x13  # ^S
DC4 = 0x14  # ^T
NAK = 0x15  # ^U
SYN = 0x16  # ^V
ETB = 0x17  # ^W
CAN = 0x18  # ^X
EM = 0x19  # ^Y
SUB = 0x1a  # ^Z
ESC = 0x1b  # ^[
FS = 0x1c  # ^\
GS = 0x1d  # ^]
RS = 0x1e  # ^^
US = 0x1f  # ^_
SP = 0x20  # space
DEL = 0x7f  # delete

DEFAULT_WIDTH = 80


class Terminal:
    """Input line editor"""

    def __init__(self, history_size=10, max_line_length=100, term_type="vt100", width=80):
        # self._orig_chan = orig_chan
        # self._orig_session = orig_session
        self._history_size = history_size if history_size > 0 else 0
        self._max_line_length = max_line_length
        self._wrap = term_type in (
            "ansi", "cygwin", "linux", "putty", "screen", "teraterm", "cit80", "vt100", "vt102", "vt220", "vt320",
            "xterm", "xterm-color", "xterm-16color", "xterm-256color", "rxvt", "rxvt-color"
        )
        self._width = width or DEFAULT_WIDTH
        self._line_mode = True
        self._echo = True
        self._start_column = 0
        self._end_column = 0
        self._cursor = 0
        self._left_pos = 0
        self._right_pos = 0
        self._pos = 0
        self._line = ""
        self._bell_rung = False
        self._early_wrap = set()
        self._outbuf = list()
        self._keymap = dict()
        self._key_state = self._keymap
        self._erased = ""
        self._history = list()
        self._history_index = 0

        for func, keys in self._keylist:
            for key in keys:
                self._add_key(key, func)

        self._build_printable()

    def _add_key(self, key, func):
        """Add a key to the keymap"""

        keymap = self._keymap

        for ch in key[:-1]:
            if ch not in keymap:
                keymap[ch] = {}

            keymap = keymap[ch]

        keymap[key[-1]] = func

    def _del_key(self, key):
        """Delete a key from the keymap"""

        keymap = self._keymap

        for ch in key[:-1]:
            if ch not in keymap:
                return

            keymap = keymap[ch]

        keymap.pop(key[-1], None)

    def _build_printable(self):
        """Build a regex of printable ASCII non-registered keys"""

        def _escape(c):
            """Backslash escape special characters in regex character range"""

            ch = chr(c)
            return ("\\" if (ch in "-&|[]\\^~") else "") + ch

        def _is_printable(ch):
            """Return if character is printable and has no handler"""

            return ch.isprintable() and ch not in keys

        pat = []
        keys = self._keymap.keys()
        start = ord(" ")
        limit = 0x10000

        while start < limit:
            while start < limit and not _is_printable(chr(start)):
                start += 1

            end = start

            while _is_printable(chr(end)):
                end += 1

            pat.append(_escape(start))

            if start != end - 1:
                pat.append("-" + _escape(end - 1))

            start = end + 1

        self._printable = re.compile("[" + "".join(pat) + "]*")

    def _char_width(self, pos):
        """Return width of character at specified position"""

        return 1 + (unicodedata.east_asian_width(self._line[pos]) in "WF") + ((pos + 1) in self._early_wrap)

    def _determine_column(self, data, column, pos=None):
        """Determine new output column after output occurs"""

        offset = pos
        last_wrap_pos = pos
        wrapped_data = []

        for ch in data:
            if ch == "\b":
                column -= 1
            else:
                if (unicodedata.east_asian_width(ch) in "WF") and (column % self._width) == self._width - 1:
                    column += 1

                    if pos is not None:
                        wrapped_data.append(data[last_wrap_pos - offset:pos - offset])
                        last_wrap_pos = pos

                        self._early_wrap.add(pos)
                else:
                    if pos is not None:
                        self._early_wrap.discard(pos)

                column += 1 + (unicodedata.east_asian_width(ch) in "WF")

            if pos is not None:
                pos += 1

        if pos is not None:
            wrapped_data.append(data[last_wrap_pos - offset:])
            return " ".join(wrapped_data), column
        else:
            return data, column

    def _output(self, data, pos=None):
        """Generate output and calculate new output column"""

        idx = data.rfind("\n")

        if idx >= 0:
            self._outbuf.append(data[:idx + 1])
            tail = data[idx + 1:]
            self._cursor = 0
        else:
            tail = data

        data, self._cursor = self._determine_column(tail, self._cursor, pos)

        self._outbuf.append(data)

        if self._cursor and self._cursor % self._width == 0:
            self._outbuf.append(" \b")

    def _ring_bell(self):
        """Ring the terminal bell"""

        if not self._bell_rung:
            self._outbuf.append("\a")
            self._bell_rung = True

    def _update_input_window(self, new_pos):
        """Update visible input window when not wrapping onto multiple lines"""

        line_len = len(self._line)

        if new_pos < self._left_pos:
            self._left_pos = new_pos
        else:
            if new_pos < line_len:
                new_pos += 1

            pos = self._pos
            column = self._cursor

            while pos < new_pos:
                column += self._char_width(pos)
                pos += 1

            if column >= self._width:
                while column >= self._width:
                    column -= self._char_width(self._left_pos)
                    self._left_pos += 1
            else:
                while self._left_pos > 0:
                    column += self._char_width(self._left_pos)

                    if column < self._width:
                        self._left_pos -= 1
                    else:
                        break

        column = self._start_column
        self._right_pos = self._left_pos

        while self._right_pos < line_len:
            ch_width = self._char_width(self._right_pos)

            if column + ch_width < self._width:
                self._right_pos += 1
                column += ch_width
            else:
                break

        return column

    def _move_cursor(self, column):
        """Move the cursor to selected position in input line"""

        start_row = self._cursor // self._width
        start_col = self._cursor % self._width

        end_row = column // self._width
        end_col = column % self._width

        if end_row < start_row:
            self._outbuf.append("\x1b[" + str(start_row - end_row) + "A")
        elif end_row > start_row:
            self._outbuf.append("\x1b[" + str(end_row - start_row) + "B")

        if end_col > start_col:
            self._outbuf.append("\x1b[" + str(end_col - start_col) + "C")
        elif end_col < start_col:
            self._outbuf.append("\x1b[" + str(start_col - end_col) + "D")

        self._cursor = column

    def _move_back(self, column):
        """Move the cursor backward to selected position in input line"""

        if self._wrap:
            self._move_cursor(column)
        else:
            self._outbuf.append("\b" * (self._cursor - column))
            self._cursor = column

    def _clear_to_end(self):
        """Clear any remaining characters from previous input line"""

        column = self._cursor
        remaining = self._end_column - column

        if remaining > 0:
            self._outbuf.append(" " * remaining)
            self._cursor = self._end_column

            if self._cursor % self._width == 0:
                self._outbuf.append(" \b")

        self._move_back(column)
        self._end_column = column

    def _erase_input(self):
        """Erase current input line"""

        self._move_cursor(self._start_column)
        self._clear_to_end()
        self._early_wrap.clear()

    def _draw_input(self):
        """Draw current input line"""

        if self._line and self._echo:
            if self._wrap:
                self._output(self._line[:self._pos], 0)
                column = self._cursor
                self._output(self._line[self._pos:], self._pos)
            else:
                self._update_input_window(self._pos)
                self._output(self._line[self._left_pos:self._pos])
                column = self._cursor
                self._output(self._line[self._pos:self._right_pos])

            self._end_column = self._cursor
            self._move_back(column)

    def _reposition(self, new_pos, new_column):
        """Reposition the cursor to selected position in input"""

        if self._echo:
            if self._wrap:
                self._move_cursor(new_column)
            else:
                self._update_input(self._pos, self._cursor, new_pos)

        self._pos = new_pos

    def _update_input(self, pos, column, new_pos):
        """Update selected portion of current input line"""

        if self._echo:
            if self._wrap:
                if pos in self._early_wrap:
                    column -= 1

                self._move_cursor(column)
                prev_wrap = new_pos in self._early_wrap
                self._output(self._line[pos:new_pos], pos)
                column = self._cursor
                self._output(self._line[new_pos:], new_pos)
                column += (new_pos in self._early_wrap) - prev_wrap
            else:
                self._update_input_window(new_pos)
                self._move_back(self._start_column)
                self._output(self._line[self._left_pos:new_pos])
                column = self._cursor
                self._output(self._line[new_pos:self._right_pos])

            self._clear_to_end()
            self._move_back(column)

        self._pos = new_pos

    def _insert_printable(self, data):
        """Insert data into the input line"""

        line_len = len(self._line)
        data_len = len(data)

        if self._max_line_length:
            if line_len + data_len > self._max_line_length:
                self._ring_bell()
                data_len = self._max_line_length - line_len
                data = data[:data_len]

        if data:
            pos = self._pos
            new_pos = pos + data_len
            self._line = self._line[:pos] + data + self._line[pos:]

            self._update_input(pos, self._cursor, new_pos)

    def _end_line(self):
        """End the current input line and send it to the session"""

        if (self._echo and not self._wrap and
                (self._left_pos > 0 or self._right_pos < len(self._line))):
            self._output("\b" * (self._cursor - self._start_column) + self._line)
        else:
            self._move_to_end()

        self._output("\r\n")

        self._start_column = 0
        self._end_column = 0
        self._cursor = 0
        self._left_pos = 0
        self._right_pos = 0
        self._pos = 0

        if self._echo and self._history_size and self._line:
            self._history.append(self._line)
            self._history = self._history[-self._history_size:]

        self._history_index = len(self._history)

        data = self._line + "\n"
        self._line = ""

        # self._session.data_received(data, None)

    def _eof_or_delete(self):
        """Erase character to the right, or send EOF if input line is empty"""

        if not self._line:
            self._session.soft_eof_received()
        else:
            self._erase_right()

    def _erase_left(self):
        """Erase character to the left"""

        if self._pos > 0:
            pos = self._pos - 1
            column = self._cursor - self._char_width(pos)
            self._line = self._line[:pos] + self._line[pos + 1:]
            self._update_input(pos, column, pos)
        else:
            self._ring_bell()

    def _erase_right(self):
        """Erase character to the right"""

        if self._pos < len(self._line):
            pos = self._pos
            self._line = self._line[:pos] + self._line[pos + 1:]
            self._update_input(pos, self._cursor, pos)
        else:
            self._ring_bell()

    def _erase_line(self):
        """Erase entire input line"""

        self._erased = self._line
        self._line = ""
        self._update_input(0, self._start_column, 0)

    def _erase_to_end(self):
        """Erase to end of input line"""

        pos = self._pos
        self._erased = self._line[pos:]
        self._line = self._line[:pos]
        self._update_input(pos, self._cursor, pos)

    def _handle_key(self, key, handler):
        """Call an external key handler"""

        result = handler(self._line, self._pos)

        if result is True:
            if key.isprintable():
                self._insert_printable(key)
            else:
                self._ring_bell()
        elif result is False:
            self._ring_bell()
        else:
            line, new_pos = result

            if new_pos < 0:
                self._session.signal_received(line)
            else:
                self._line = line
                self._update_input(0, self._start_column, new_pos)

    def _history_prev(self):
        """Replace input with previous line in history"""

        if self._history_index > 0:
            self._history_index -= 1
            self._line = self._history[self._history_index]
            self._update_input(0, self._start_column, len(self._line))
        else:
            self._ring_bell()

    def _history_next(self):
        """Replace input with next line in history"""

        if self._history_index < len(self._history):
            self._history_index += 1

            if self._history_index < len(self._history):
                self._line = self._history[self._history_index]
            else:
                self._line = ""

            self._update_input(0, self._start_column, len(self._line))
        else:
            self._ring_bell()

    def _move_left(self):
        """Move left in input line"""

        if self._pos > 0:
            pos = self._pos - 1
            column = self._cursor - self._char_width(pos)
            self._reposition(pos, column)
        else:
            self._ring_bell()

    def _move_right(self):
        """Move right in input line"""

        if self._pos < len(self._line):
            pos = self._pos
            column = self._cursor + self._char_width(pos)
            self._reposition(pos + 1, column)
        else:
            self._ring_bell()

    def _move_to_start(self):
        """Move to start of input line"""

        self._reposition(0, self._start_column)

    def _move_to_end(self):
        """Move to end of input line"""

        self._reposition(len(self._line), self._end_column)

    def _redraw(self):
        """Redraw input line"""

        self._erase_input()
        self._draw_input()

    def _insert_erased(self):
        """Insert previously erased input"""

        self._insert_printable(self._erased)

    def _send_break(self):
        """Send break to session"""

        self._session.break_received(0)

    # pylint: disable=bad-whitespace

    _keylist = ((_end_line, ("\n", "\r", "\x1bOM")),
                (_eof_or_delete, ("\x04",)),
                (_erase_left, ("\x08", "\x7f")),
                (_erase_right, ("\x1b[3~",)),
                (_erase_line, ("\x15",)),
                (_erase_to_end, ("\x0b",)),
                (_history_prev, ("\x10", "\x1b[A", "\x1bOA")),
                (_history_next, ("\x0e", "\x1b[B", "\x1bOB")),
                (_move_left, ("\x02", "\x1b[D", "\x1bOD")),
                (_move_right, ("\x06", "\x1b[C", "\x1bOC")),
                (_move_to_start, ("\x01", "\x1b[H", "\x1b[1~")),
                (_move_to_end, ("\x05", "\x1b[F", "\x1b[4~")),
                (_redraw, ("\x12",)),
                (_insert_erased, ("\x19",)),
                (_send_break, ("\x03", "\x1b[33~")))

    # pylint: enable=bad-whitespace

    def register_key(self, key, handler):
        """Register a handler to be called when a key is pressed"""

        self._add_key(key, partial(SSHLineEditor._handle_key,
                                   key=key, handler=handler))
        self._build_printable()

    def unregister_key(self, key):
        """Remove the handler associated with a key"""

        self._del_key(key)
        self._build_printable()

    def set_input(self, line, pos):
        """Set input line and cursor position"""

        self._line = line
        self._update_input(0, self._start_column, pos)

    def set_line_mode(self, line_mode):
        """Enable/disable input line editing"""

        if self._line and not line_mode:
            data = self._line
            self._erase_input()
            self._line = ""

            self._session.data_received(data, None)

        self._line_mode = line_mode

    def set_echo(self, echo):
        """Enable/disable echoing of input in line mode"""

        if self._echo and not echo:
            self._erase_input()
            self._echo = False
        elif echo and not self._echo:
            self._echo = True
            self._draw_input()

    def set_width(self, width):
        """Set terminal line width"""

        self._width = width or DEFAULT_WIDTH

        if self._wrap:
            _, self._cursor = self._determine_column(self._line, self._start_column, 0)

        self._redraw()

    def process_input(self, data, datatype):
        """Process input from channel"""

        if self._line_mode:
            data_len = len(data)
            idx = 0

            while idx < data_len:
                ch = data[idx]
                idx += 1

                if ch in self._key_state:
                    self._key_state = self._key_state[ch]
                    if callable(self._key_state):
                        try:
                            self._key_state(self)
                        finally:
                            self._key_state = self._keymap
                elif self._key_state == self._keymap and ch.isprintable():
                    match = self._printable.match(data, idx - 1)[0]

                    if match:
                        self._insert_printable(match)
                        idx += len(match) - 1
                    else:
                        self._insert_printable(ch)
                else:
                    self._key_state = self._keymap
                    self._ring_bell()

            self._bell_rung = False
            self.write("".join(self._outbuf))
            self._outbuf.clear()
        else:
            self._session.data_received(data, datatype)

    def process_output(self, data):
        """Process output to channel"""

        data = data.replace("\n", "\r\n")

        self._erase_input()
        self._output(data)

        if not self._wrap:
            self._cursor %= self._width

        self._start_column = self._cursor
        self._end_column = self._cursor
        self._draw_input()

        self._chan.write("".join(self._outbuf))
        self._outbuf.clear()

    def __getattr__(self, attr):
        """Delegate most channel functions to original channel"""

        return getattr(self._orig_chan, attr)

    def create_editor(self):
        """Create input line editor if encoding and terminal type are set"""
        return self

    def clear_input(self):
        """Clear input line
           This method clears the current input line.
        """

        self.set_input("", 0)

    def write(self, data, datatype=None):
        """Process data written to the channel"""

        # if self._editor and datatype is None:
        #    self._editor.process_output(data)
        # else:
        #    self._orig_chan.write(data, datatype)
        print(data)

    def session_started(self):
        """Start a session for this newly opened server channel"""

        # self._editor = self._chan.create_editor()
        # self._orig_session.session_started()

        self.create_editor()

    def terminal_size_changed(self, width, height, pixwidth, pixheight):
        """The terminal size has changed"""

        if self._editor:
            self._editor.set_width(width)

        self._orig_session.terminal_size_changed(width, height, pixwidth, pixheight)

    def data_received(self, data, datatype):
        """Process data received from the channel"""
        self.process_input(data, datatype)

    def eof_received(self):
        """Process EOF received from the channel"""

        if self._editor:
            self._editor.set_line_mode(False)

        return self._orig_session.eof_received()


from angelos.common.utils import Util

"""
Control sequence = CSI = ESC [
F = A control sequence, where F is from 0o100 to 0o176 inclusive.


Escape sequence = ESC
F = An escape sequence, where F is from 0o60 to 0o176 inclusive

An intermediate character in an escape sequence or a control sequence, where I is from 0o40 to 0o57 inclusive.


All of the following escape and control sequences are transmitted from the host computer to the VT100 unless otherwise noted

CPR – Cursor Position Report – VT100 to Host
ESC [ Pn ; Pn R

CUB – Cursor Backward – Host to VT100 and VT100 to Host
ESC [ Pn D

CUD – Cursor Down – Host to VT100 and VT100 to Host
ESC [ Pn B

CUF – Cursor Forward – Host to VT100 and VT100 to Host
ESC [ Pn C

CUP – Cursor Position
ESC [ Pn ; Pn H

CUU – Cursor Up – Host to VT100 and VT100 to Host
ESC [ Pn A

DA – Device Attributes
ESC [ Pn c

DECALN – Screen Alignment Display (DEC Private)
ESC # 8

DECDHL – Double Height Line (DEC Private)
Top Half: ESC # 3	 
Bottom Half: ESC # 4

DECDWL – Double-Width Line (DEC Private)
ESC # 6

DECID – Identify Terminal (DEC Private)
ESC Z

DECKPAM – Keypad Application Mode (DEC Private)
ESC =

DECKPNM – Keypad Numeric Mode (DEC Private)
ESC >

DECLL – Load LEDS (DEC Private)
ESC [ Ps q	default value: 0

DECRC – Restore Cursor (DEC Private)
ESC 8

DECREPTPARM – Report Terminal Parameters
ESC [ <sol>; <par>; <nbits>; <xspeed>; <rspeed>; <clkmul>; <flags> x

DECREQTPARM – Request Terminal Parameters
ESC [ <sol> x

DECSC – Save Cursor (DEC Private)
ESC 7

DECSTBM – Set Top and Bottom Margins (DEC Private)
ESC [ Pn; Pn r

DECSWL – Single-width Line (DEC Private)
ESC # 5

DECTST – Invoke Confidence Test
ESC [ 2 ; Ps y

DSR – Device Status Report
ESC [ Ps n

ED – Erase In Display
ESC [ Ps J

EL – Erase In Line
ESC [ Ps K

HTS – Horizontal Tabulation Set
ESC H

HVP – Horizontal and Vertical Position
ESC [ Pn ; Pn f

IND – Index
ESC D

NEL – Next Line
ESC E

RI – Reverse Index
ESC M

RIS – Reset To Initial State
ESC c

RM – Reset Mode
ESC [ Ps ; Ps ; . . . ; Ps l

SCS – Select Character Set
G0 Sets Sequence	G1 Sets Sequence	Meaning
ESC ( A	ESC ) A	United Kingdom Set
ESC ( B	ESC ) B	ASCII Set
ESC ( 0	ESC ) 0	Special Graphics
ESC ( 1	ESC ) 1	Alternate Character ROM Standard Character Set
ESC ( 2	ESC ) 2	Alternate Character ROM Special Graphics

SGR – Select Graphic Rendition
ESC [ Ps ; . . . ; Ps m

SM – Set Mode
ESC [ Ps ; . . . ; Ps h

TBC – Tabulation Clear
ESC [ Ps g

Cursor Up
ESC A

Cursor Down
ESC B

Cursor Right
ESC C

Cursor Left
ESC D

Enter Graphics Mode
ESC F

Exit Graphics Mode
ESC G

Cursor to Home
ESC H

Reverse Line Feed
ESC I

Erase to End of Screen
ESC J

Erase to End of Line
ESC K

Direct Cursor Address
ESC Y line column

Identify
ESC Z
ESC / Z

Enter Alternate Keypad Mode
ESC =

Exit Alternate Keypad Mode
ESC >

Enter ANSI Mode
ESC <

Cursor up	ESC [ Pn A
Cursor down	ESC [ Pn B
Cursor forward (right)	ESC [ Pn C
Cursor backward (left)	ESC [ Pn D
Direct cursor addressing	ESC [ Pl ; Pc H† or
ESC [ Pl ; Pc f†
Index	ESC D
New line	ESC E
Reverse index	ESC M
Save cursor and attributes	ESC 7
Restore cursor and attributes	ESC 8

Change this line to double-height top half	ESC # 3
Change this line to double-height bottom half	ESC # 4
Change this line to single-width single-height	ESC # 5
Change this line to double-width single-height	ESC # 6

Character Attributes
ESC [ Ps;Ps;Ps;...;Ps m

From cursor to end of line	ESC [ K or ESC [ 0 K
From beginning of line to cursor	ESC [ 1 K
Entire line containing cursor	ESC [ 2 K
From cursor to end of screen	ESC [ J or ESC [ 0 J
From beginning of screen to cursor	ESC [ 1 J
Entire screen	ESC [ 2 J

Programmable LEDs
ESC [ Ps;Ps;...Ps q

United Kingdom (UK)	ESC ( A	ESC ) A
United States (USASCII)	ESC ( B	ESC ) B
Special graphics characters and line drawing set	ESC ( 0	ESC ) 0
Alternate character ROM	ESC ( 1	ESC ) 1
Alternate character ROM special graphics characters	ESC ( 2	ESC ) 2

Scrolling Region
ESC [ Pt ; Pb r

Set tab at current column	ESC H
Clear tab at current column	ESC [ g or ESC [ 0 g
Clear all tabs	ESC [ 3 g

Line feed/new line	New line	ESC [20h	Line feed	ESC [20l*
Cursor key mode	Application	ESC [?1h	Cursor	ESC [?1l*
ANSI/VT52 mode	ANSI	N/A	VT52	ESC [?2l*
Column mode	132 Col	ESC [?3h	80 Col	ESC [?3l*
Scrolling mode	Smooth	ESC [?4h	Jump	ESC [?4l*
Screen mode	Reverse	ESC [?5h	Normal	ESC [?5l*
Origin mode	Relative	ESC [?6h	Absolute	ESC [?6l*
Wraparound	On	ESC [?7h	Off	ESC [?7l*
Auto repeat	On	ESC [?8h	Off	ESC [?8l*
Interlace	On	ESC [?9h	Off	ESC [?9l*
Keypad mode	Application	ESC =	Numeric	ESC >

Invoked by	ESC [ 6 n
Response is	ESC [ Pl ; Pc R †

Invoked by	ESC [ 5 n
Response is	ESC [ 0 n (terminal ok)
ESC [ 3 n (terminal not ok)

Invoked by	ESC [ c or ESC [ 0 c
Response is	ESC [ ? 1 ; Ps c

ESC c

Fill Screen with "Es"	ESC # 8
Invoke Test(s)	ESC [ 2 ; Ps y

Cursor Up	ESC A	 
Cursor Down	ESC B	 
Cursor Right	ESC C	 
Cursor Left	ESC D	 
Select Special Graphics character set	ESC F	 
Select ASCII character set	ESC G	 
Cursor to home	ESC H	 
Reverse line feed	ESC I	 
Erase to end of screen	ESC J	 
Erase to end of line	ESC K	 
Direct cursor address	ESC Y l c	(see note 1)
Identify	ESC Z	(see note 2)
Enter alternate keypad mode	ESC =	 
Exit alternate keypad mode	ESC >	 
Enter ANSI mode	ESC <
"""


REGEX = r"""(\x1B\[[\x40-\x7E]*[\x20-\x2F]|\x1B[\x30-\x7E]*[\x20-\x2F]|[\x00-\x1F])"""  # (CSI I F|ESC I F)


class TTYCodes:
    class SeqCodes:
        """Control and escape sequence codes for the VT100."""

        CTRL_SP = " "  # Space
        CTRL_NUL = "\x00"  # Null
        CTRL_BEL = "\x07"  # Beep
        CTRL_BS = "\x08"  # Backspace
        CTRL_HT = "\x09"  # Tab
        CTRL_LF = "\n"  # New line
        CTRL_VT = "\x0b"  # Vertical tab
        CTRL_FF = "\x0c"  # Form feed
        CTRL_CR = "\r"  # Carriage return
        CTRL_SO = "\x0e"  # Shift out
        CTRL_SI = "\x0f"  # Shift in
        CTRL_CAN = "\x18"  # Cancel
        CTRL_SUB = "\x1a"  # Substitute
        CTRL_ESC = "\x1b"  # Escape
        CTRL_DEL = "\x7f"  # Delete
        CTRL_CSI_C0 = "\x1b["  # Control sequence introducer
        CTRL_CSI_C1 = "\x9b"  # Control sequence introducer
        CTRL_CSI = "\x1b["  # Control sequence introducer
        CTRL_ST_C0 = "\x1b\\"  # String terminator
        CTRL_ST_C1 = "\x9c"  # String terminator
        CTRL_ST = "\x1b\\"  # String terminator
        CTRL_OSC_C0 = "\x1b]"  # OS command
        CTRL_OSC_C1 = "\x9d"  # OS command
        CTRL_OSC = "\x1b]"  # OS command

        ESC_RIS = "c"  # Reset
        ESC_IND = "D"  # Index
        ESC_NEL = "E"  # Next line
        ESC_HTS = "H"  # Tabulation set
        ESC_RI = "M"  # Reverse index
        ESC_DECSC = "7"  # Save cursor
        ESC_DECRC = "8"  # Restore cursor
        ESC_DECALN = "8"  # Alignment display
        ESC_ICH = "@"  # Insert character
        ESC_CUU = "A"  # Cursor up
        ESC_CUD = "B"  # Cursor down
        ESC_CUF = "C"  # Cursor forward
        ESC_CUB = "D"  # Cursor back
        ESC_CNL = "E"  # Cursor next line
        ESC_CPL = "F"  # Cursor previous line
        ESC_CHA = "G"  # Cursor horizontal align
        ESC_CUP = "H"  # Cursor position
        ESC_ED = "J"  # Erase data
        ESC_EL = "K"  # Erase in line
        ESC_IL = "L"  # Insert line
        ESC_DL = "M"  # Delete line
        ESC_DCH = "P"  # Delete character
        ESC_ECH = "X"  # Erase character
        ESC_HPR = "a"  # Horizontal position relative
        ESC_DA = "c"  # Device attributes
        ESC_VPA = "d"  # Vertical position adjust
        ESC_VPR = "e"  # Vertical position relative
        ESC_HVP = "f"  # Horizontal / vertical position
        ESC_TBC = "g"  # Tabulation clear
        ESC_SM = "h"  # Set mode
        ESC_RM = "l"  # Reset mode
        ESC_SGR = "m"  # Select graphics rendition
        ESC_DSR = "n"  # Device status report
        ESC_DECSTBM = "r"  # Select top and bottom margins
        ESC_HPA = "'"  # Horizontal adjust

    class GraphicsCodes:
        """Graphic codes for VT100."""

        BOLD = 1
        ITALICS = 3
        UNDERSCORE = 4
        BLINK = 5
        REVERSE = 7
        STRIKE = 9
        BOLD_RM = 22
        ITALICS_RM = 23
        UNDERSCORE_RM = 24
        BLINK_RM = 25
        REVERSE_RM = 27
        STRIKE_RM = 29

        FG_BLACK = 30
        FG_RED = 31
        FG_GREEN = 32
        FG_BROWN = 33
        FG_BLUE = 34
        FG_MAGENTA = 35
        FG_CYAN = 36
        FG_WHITE = 37
        FG_DEFAULT = 39  # White

        FG_BRIGHTBLACK = 90
        FG_BRIGHTRED = 91
        FG_BRIGHTGREEN = 92
        FG_BRIGHTBROWN = 93
        FG_BRIGHTBLUE = 94
        FG_BRIGHTMAGENTA = 95
        FG_BRIGHTCYAN = 96
        FG_BRIGHTWHITE = 97

        BG_BLACK = 40
        BG_RED = 41
        BG_GREEN = 42
        BG_BROWN = 43
        BG_BLUE = 44
        BG_MAGENTA = 45
        BG_CYAN = 46
        BG_WHITE = 47
        BG_DEFAULT = 49  # Black

        BG_BRIGHTBLACK = 100
        BG_BRIGHTRED = 101
        BG_BRIGHTGREEN = 102
        BG_BRIGHTBROWN = 103
        BG_BRIGHTBLUE = 104
        BG_BRIGHTMAGENTA = 105
        BG_BRIGHTCYAN = 106
        BG_BRIGHTWHITE = 107

    class ModeCodes:
        """Line feed modes for VT100"""

        LNM = 20  # Line feed / New line mode
        IRM = 4  # Insert / Replace mode
        DECTCEM = 25 << 5  # Text cursor enable mode
        DECSCNM = 5 << 5  # Screen mode
        DECOM = 6 << 5  # Origin mode
        DECAWM = 7 << 5  # Auto wrap mode
        DECCOLM = 3 << 5  # Column mode



class Application:
    """Test application for terminal emulator."""

    def __init__(self):
        self._quiter = None
        self._task = None

        self._tty = sys.stdin.fileno()
        self._echo = termios.tcgetattr(self._tty)
        self._no_echo = copy.copy(self._echo)
        self._no_echo[3] = self._no_echo[3] & ~termios.ECHO

        self._terminal = None

    def _quit(self):
        self._quiter.set()

    def _sigint_handler(self):
        self.on_quit()
        self._quit()

    def _sigwinch_handler(self):
        size = os.get_terminal_size()
        self.on_resize(size.columns, size.lines)

    def _input_handler(self):
        self.on_input(sys.stdin.buffer.read1())

    def _build_parser(self) -> ArgumentParser:
        """Build argument parser."""
        parser = ArgumentParser("Angelos Admin Utility")
        parser.add_argument("-v", "--verbose", dest="verbose", default=False, help="Verbose output")

        return parser

    def on_quit(self):
        """Override this method to act upon program quit."""
        pass

    def on_resize(self, columns: int, lines: int):
        """Override this method to act upon terminal resize."""
        print(columns, lines)

    def on_input(self, text: str):
        """Override this method to act upon user keypress."""
        print("Seq:", text)
        # self._terminal.data_received(text, str)

    async def _initialize(self):
        # self._terminal = Terminal()
        tty.setraw(self._tty)

        self._quiter = asyncio.Event()
        self._quiter.clear()

        asyncio.get_event_loop().add_signal_handler(
            signal.CTRL_C_EVENT if os.name == "nt" else signal.SIGINT, self._sigint_handler)
        asyncio.get_event_loop().add_signal_handler(signal.SIGWINCH, self._sigwinch_handler)

        asyncio.get_event_loop().add_reader(sys.stdin, self._input_handler)

        args = self._build_parser().parse_args()
        # self._terminal.session_started()
        # termios.tcsetattr(self._tty, termios.TCSADRAIN, self._no_echo)

    async def _finalize(self):
        termios.tcsetattr(self._tty, termios.TCSADRAIN, self._echo)

    async def run(self):
        """Application main loop."""
        await self._initialize()
        await self._quiter.wait()
        await self._finalize()

    def start(self):
        """Start application main loop."""
        try:
            asyncio.run(self.run())
        except KeyboardInterrupt:
            print("Uncaught keyboard interrupt")
        except Exception as exc:
            Util.print_exception(exc)


if __name__ == "__main__":
    Application().start()
