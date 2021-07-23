# cython: language_level=3, linetrace=True
#
# Copyright (c) 2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""Virtual terminal emulator.
Implemented mostly according to https://en.wikipedia.org/wiki/ANSI_escape_code
and this too https://en.wikipedia.org/wiki/ASCII
"""
from unicodedata import east_asian_width

cdef inline int utf8_len(unsigned char byte) nogil:
    if 0x20 <= byte <= 0x7E:
        return 1
    if byte >> 5 == 6:
        return 2
    if byte >> 4 == 14:
        return 3
    if byte >> 3 == 30:
        return 4
    return 0

cdef inline long long imax(long long a, long long b) nogil:
    """Maximum integer is returned."""
    return a if a > b else b

cdef inline long long imin(long long a, long long b) nogil:
    """Minimum integer is returned. """
    return a if a < b else b


cdef class ByteList:
    """Bytes object with read/write access."""

    cdef readonly unsigned long length;
    cdef unsigned char *_view;
    cdef bytes _data

    def __init__(self, data: bytes):
        self._data = data
        self.length = len(data)
        self._view = <unsigned char*> data

    @property
    def data(self) -> bytes:
        """Access data buffer."""
        return self._data

    def __len__(self):
        return self.length

    cdef inline unsigned char get(self, unsigned int index) nogil:
        """Get value at given index or zero."""
        if index >= self.length:
            return 0
        return self._view[index]

    cdef inline void set(self, unsigned int index, unsigned char value) nogil:
        """Get value at given index."""
        if index < self.length:
            self._view[index] = value

    cdef inline void reset(self, unsigned char value = 0) nogil:
        """Get value at given index."""
        cdef unsigned long index = 0
        while index < self.length:
            self._view[index] = value
            index += 1


cdef class ByteIterator:
    """Bytes object iterator with close to C speed."""

    cdef readonly bint end;
    cdef readonly unsigned long length;
    cdef unsigned long _index;
    cdef unsigned char *_view;
    cdef bytes _data

    def __init__(self, data: bytes):
        self._data = data
        self._index = 0
        self.length = len(data)
        self._view = <unsigned char*> data
        self.end = not bool(self.length)

    @property
    def data(self) -> bytes:
        """Access data buffer."""
        return self._data

    cdef inline unsigned char next(self) nogil:
        """Next byte in stream. If ended it returns a 0."""
        if self.end:
            return 0
        self._index += 1
        if self._index == self.length:
            self.end = True
        return self._view[self._index - 1]


cdef enum CellAttributeCodes:
    attrBOLD = 1 << 0  # Flag for bold bit
    attrDIM = 1 << 1  # Flag for dim bit
    attrITALIC = 1 << 2  # Flag for italic bit
    attrUNDER = 1 << 3  # Flag for underscore bit
    attrBLINK = 1 << 4  # Flag for blink bit
    attrINVERT = 1 << 5  # Flag for invert bit
    attrSTRIKE = 1 << 6  # Flag for strike bit

cdef enum ForegroundCodes:
    fgBLACK = 30
    fgRED = 31
    fgGREEN = 32
    fgBROWN = 33
    fgBLUE = 34
    fgMAGENTA = 35
    fgCYAN = 36
    fgWHITE = 37
    fgDEFAULT = 39  # White
    fgBRIGHT_BLACK = 90
    fgBRIGHT_RED = 91
    fgBRIGHT_GREEN = 92
    fgBRIGHT_BROWN = 93
    fgBRIGHT_BLUE = 94
    fgBRIGHT_MAGENTA = 95
    fgBRIGHT_CYAN = 96
    fgBRIGHT_WHITE = 97

cdef enum BackgroundCodes:
    bgBLACK = 40
    bgRED = 41
    bgGREEN = 42
    bgBROWN = 43
    bgBLUE = 44
    bgMAGENTA = 45
    bgCYAN = 46
    bgWHITE = 47
    bgDEFAULT = 49  # Black
    bgBRIGHT_BLACK = 100
    bgBRIGHT_RED = 101
    bgBRIGHT_GREEN = 102
    bgBRIGHT_BROWN = 103
    bgBRIGHT_BLUE = 104
    bgBRIGHT_MAGENTA = 105
    bgBRIGHT_CYAN = 106
    bgBRIGHT_WHITE = 107

cdef enum CtrlCodes:
    ctrlBEL = 0x07  # Bell
    ctrlBS = 0x08  # Backspace
    ctrlHT = 0x09  # Horizontal Tab
    ctrlLF = 0x0A  # Line Feed
    ctrlFF = 0x0C  # Form Feed
    ctrlCR = 0x0D  # Carriage Return
    ctrlESC = 0x1B  # Escape

cdef enum EscCodes:
    escSS2 = 0x8E  # Single Shift Two
    escSS3 = 0x8F  # Single Shift Three
    escDCS = 0x90  # Device Control String
    escCSI = 0x5B  # Control Sequence Introducer C0
    escCSI1 = 0x9B  # Control Sequence Introducer C1
    escST = 0xfC  # String Terminator C0
    escST1 = 0x9C  # String Terminator C1
    escOSC = 0x5D  # Operating System Command C0
    escOSC1 = 0x9D  # Operating System Command C1
    escSOS = 0x98  # Start of String
    escPM = 0x9E  # Privacy Message
    escAPC = 0x9F  # Application Program Command

cdef enum CsiCodes:
    csiCUU = 0x41  # Cursor Up
    csiCUD = 0x42  # Cursor Down
    csiCUF = 0x43  # Cursor Forward
    csiCUB = 0x44  # Cursor Back
    csiCNL = 0x45  # Cursor Next Line
    csiCPL = 0x46  # Cursor Previous Line
    csiCHA = 0x47  # Cursor Horizontal Absolute
    csiCUP = 0x48  # Cursor Position
    csiED = 0x4A  # Erase in Display
    csiEL = 0x4B  # Erase in Line
    csiSU = 0x53  # Scroll Up
    csiCSD = 0x54  # Scroll Down
    csiHVP = 0x66  # Horizontal Vertical Position
    csiSGR = 0x6d  # Select Graphic Rendition
    csiAUX = 0x69  # AUX Port
    csiDSR = 0x6E  # Device Status Report
    cisSCP = 0x73  #  Save Current Cursor Position
    csiRCP = 0x75  #  Restore Saved Cursor Position
    csiVT = 0x7E  # VT Sequences

cdef enum SgrCodes:
    sgrRESET = 0  # Reset or normal
    sgrBOLD_ON = 1  # Bold or increased intensity
    sgrDIM_ON = 2  # Faint, decreased intensity, or dim
    sgrITALIC_ON = 3  # Italic
    sgrUNDERLINE_ON = 4  # Underline
    sgrBLINK_ON = 5  # Slow blink
    sgrINVERT_ON = 7  # Reverse video or invert
    sgrSTRIKE_ON = 9  # Crossed-out, or strike
    sgrBOLD_OFF = 22  # Normal intensity
    sgrDIM_OFF = 22  # Normal intensity
    sgrITALIC_OFF = 23  # Neither italic, nor blackletter
    sgrUNDERLINE_OFF = 24  # Not underlined
    sgrBLINK_OFF = 25  # Not blinking
    sgrINVERT_OFF = 27  # Not reversed
    sgrSTRIKE_OFF = 29  # Not crossed out

cdef enum VtCodes:
    vtHome = 1
    vtInsert = 2
    vtDelete = 3
    vtEnd = 4
    vtPgUp = 5
    vtPgDn = 6
    vtHome2 = 7
    vtEnd2 = 8
    vtF0 = 10
    vtF1 = 11
    vtF2 = 12
    vtF3 = 13
    vtF4 = 14
    vtF5 = 15
    vtF6 = 17
    vtF7 = 18
    vtF8 = 19
    vtF9 = 20
    vtF10 = 21
    vtF11 = 23
    vtF12 = 24
    vtF13 = 25
    vtF14 = 26
    vtF15 = 28
    vtF16 = 29
    vtF17 = 31
    vtF18 = 32
    vtF19 = 33
    vtF20 = 34

ctypedef struct Glyph:
    unsigned char[4] units

ctypedef struct Dirty:
    bint updated
    unsigned short begin
    unsigned short end


import logging
logger = logging.getLogger()


cdef class Screen:
    """
    Pseudo terminal screen.

    The lines and columns in the ANSI escape code de facto standard seems to be 1-indexed instead of zero-indexed.
    However the screen uses _x and _y as zero-indexed.
    """

    cdef unsigned short _cols;  # Terminal width
    cdef unsigned short _lines;  # Terminal height
    cdef unsigned short _x;  # Cursor position
    cdef unsigned short _y;  # Cursor position

    cdef unsigned char _fg;  # Current foreground color
    cdef unsigned char _bg;  # Current background color
    cdef unsigned char _attr;  # Current cell attributes

    cdef Dirty *_modified;

    cdef bytes _empty;
    cdef list _buffer;
    cdef ByteList _current;
    cdef str _line;
    cdef list _history;

    cdef bytes _modified_bytes;

    def __cinit__(self):
        self._x = 0
        self._y = 0
        self._cols = 1
        self._lines = 1

        self._fg = fgDEFAULT
        self._bg = bgDEFAULT
        self._attr = 0

        self._modified = NULL

    def __init__(self, cols: int, lines: int):
        # self._empty = self._tileplate()  # Template cell
        self._buffer = list()  # Buffer of cells
        self._current = None  # Current selected line from buffer
        self._line = ""  # Editorial string
        self._history = list()  # List of historical lines

        self._cols = cols
        self._lines = lines

        for _ in range(self._lines):
            self._buffer.append(self._new_line(self._cols))

        self._current_line()
        self._new_modified()

    @property
    def x(self) -> int:
        """Cursor X position, 1-indexed."""
        return self._x + 1

    @property
    def y(self) -> int:
        """Cursor Y position, 1-indexed."""
        return self._y

    @property
    def columns(self) -> int:
        """Width of the PTY."""
        return self._cols

    @property
    def lines(self) -> int:
        """Height of the PTY."""
        return self._lines

    # def _tileplate(self) -> bytes:
    #    """Templates a tile from input data and returns it as bytes."""
    #    return bytes([32, 0, 0, 0, self._fg, self._bg, self._attr])

    cdef ByteList _new_line(self, unsigned int cols):
        """Create a new line for the buffer, returns a tuple of bytes data and cython Tile memoryview."""
        cdef unsigned long idx = 0
        cdef Glyph glyph
        cdef ByteList byte_list = ByteList(bytes(cols * 7))

        glyph.units[0] = 32
        glyph.units[1] = 0
        glyph.units[2] = 0
        glyph.units[3] = 0

        while idx < self._cols:
            self._print(byte_list, idx, &glyph)
            idx += 1

        return byte_list

    cdef ByteList _resize_line(self, unsigned int y, unsigned int cols):
        """Resizes an existing line buffer preserving data."""
        cdef ByteList byte_list = self._buffer[y]
        cdef unsigned int size = byte_list.length // 7

        if size > cols:
            return ByteList(byte_list.data[:cols * 7])
        elif size < cols:
            return ByteList(byte_list.data + bytes((cols - size) * 7))
        else:
            return byte_list

    def _resize(self, unsigned short lines, unsigned short cols):
        """Resize screen."""
        if self._lines > lines:
            self._buffer = self._buffer[-lines:]
            for y in range(lines):
                self._buffer[y] = self._resize_line(y, cols)
        elif self._lines < lines:
            for y in range(self._lines):
                self._buffer[y] = self._resize_line(y, cols)
            for _ in range(lines - self._lines):
                self._buffer.append(self._new_line(cols))

        self._lines = lines
        self._cols = cols
        self._current_line()
        self._new_modified()

    cdef inline void _current_line(self):
        """Prepare current line when cursor changes vertically."""
        self._current = self._buffer[self._y]

    def _new_modified(self):
        """Create a buffer of dirty screen information."""
        cdef Dirty *modified_array = NULL
        modified = bytes(self._lines * sizeof(Dirty))
        self._modified_bytes = modified
        modified_array = <Dirty*> modified
        self._modified = modified_array

    cdef inline void _update(self):
        """Mark tiles as modified."""
        cdef unsigned short y = self._y

        # if self._modified[y].updated:
        #    self._modified[y].begin = imax(0, imin(self._modified[y].begin, self._x-1))
        #    self._modified[y].end = imin(self._cols-1, imax(self._modified[y].end, self._x))
        # else:
        #    self._modified[y].updated = True
        #    self._modified[y].begin = imax(0, self._x-1)
        #    self._modified[y].end = imin(self._cols-1, self._x-1)

        if self._modified[y].updated:
            self._modified[y].begin = imin(self._modified[y].begin, self._x)
            self._modified[y].end = imax(self._modified[y].end, self._x + 1)
        else:
            self._modified[y].updated = True
            self._modified[y].begin = self._x
            self._modified[y].end = self._x + 1

    cpdef _clear(self):
        """Clears all marks of modification."""
        cdef unsigned short idx = 0

        with nogil:
            while idx < self._lines:
                self._modified[idx].updated = False
                idx += 1

    cpdef void _smear(self):
        """Marks all tiles as modified."""
        cdef unsigned short idx = 0

        with nogil:

            while idx < self._lines:
                self._modified[idx].updated = True
                self._modified[idx].begin = 0
                self._modified[idx].end = self._cols - 1
                idx += 1

    cdef inline void _print(self, ByteList view, unsigned short x, Glyph *glyph):
        """Print a glyph to the buffer using colors and attributes."""
        cdef unsigned long pos = x * 7

        view.set(pos, glyph.units[0])
        view.set(pos + 1, glyph.units[1])
        view.set(pos + 2, glyph.units[2])
        view.set(pos + 3, glyph.units[3])
        view.set(pos + 4, self._fg)
        view.set(pos + 5, self._bg)
        view.set(pos + 6, self._attr)

    cdef inline void _move_up(self, unsigned short steps):
        """Move the cursor position up Y steps."""
        if (self._y - steps) < 0:
            self._y = 0
        else:
            self._y -= steps

    cdef inline void _move_down(self, unsigned short steps):
        """Move the cursor position down Y steps."""
        if (self._y + steps) > (self._lines - 1):
            self._y = self._lines - 1
        else:
            self._y += steps

    cdef inline void _move_left(self, unsigned short steps):
        """Move the cursor position left X steps."""
        if (self._x - steps) < 0:
            self._x = 0
        else:
            self._x -= steps

    cdef inline void _move_right(self, unsigned short steps):
        """Move the cursor position right X steps."""
        if (self._x + steps) > (self._cols - 1):
            self._x = self._cols - 1
        else:
            self._x += steps

    cdef inline void _goto_x(self, unsigned short pos):
        """Move the cursor to position X."""
        if pos < 0:
            self._x = 0
        elif pos > (self._cols - 1):
            self._x = self._cols - 1
        else:
            self._x = pos

    cdef inline void _goto_y(self, unsigned short pos):
        """Move the cursor to position Y."""
        if pos < 0:
            self._y = 0
        elif pos > (self._lines - 1):
            self._y = self._lines - 1
        else:
            self._y = pos

    cdef inline void print_glyph(self, Glyph *glyph):
        """Print glyph to console."""
        self._print(self._current, self._x, glyph)
        self._update()
        self._move_right(1)

    cdef inline void bell(self):
        """Executes the BEL control character."""
        pass

    cdef inline void backspace(self):
        """Executes the BS control character."""
        pass

    cdef inline void tab(self):
        """Executes the HT control character."""
        pass

    cdef inline void line_feed(self):
        """Executes the LF control character."""
        pass

    cdef inline void form_feed(self):
        """Executes the FF control character."""
        pass

    cdef inline void carriage_return(self):
        """Executes the CR control character."""
        pass

    cdef inline void escape(self):
        """Executes the ESC control character."""
        pass

    cdef inline void cursor_up(self, unsigned short steps):
        """
        Moves the cursor n (default 1) cells up. 
        If the cursor is already at the edge of the screen, this has no effect.
        """
        self._move_up(steps if steps > 1 else 1)
        self._current_line()

    cdef inline void cursor_down(self, unsigned short steps):
        """
        Moves the cursor n (default 1) cells down. 
        If the cursor is already at the edge of the screen, this has no effect.
        """
        self._move_down(steps if steps > 1 else 1)
        self._current_line()

    cdef inline void cursor_forward(self, unsigned short steps):
        """
        Moves the cursor n (default 1) cells forward. 
        If the cursor is already at the edge of the screen, this has no effect.
        """
        self._move_right(steps if steps > 1 else 1)

    cdef inline void cursor_back(self, unsigned short steps):
        """
        Moves the cursor n (default 1) cells previous. 
        If the cursor is already at the edge of the screen, this has no effect.
        """
        self._move_left(steps if steps > 1 else 1)

    cdef inline void cursor_next_line(self, unsigned short downs):
        """Moves cursor to beginning of the line n (default 1) lines down."""
        self._move_down(downs if downs > 1 else 1)
        self._goto_x(0)
        self._current_line()

    cdef inline void cursor_previous_line(self, unsigned short ups):
        """Moves cursor to beginning of the line n (default 1) lines up."""
        self._move_down(ups if ups > 1 else 1)
        self._goto_x(0)
        self._current_line()

    cdef inline void cursor_horizontal_absolute(self, unsigned short x):
        """Moves the cursor to column n (default 1)."""
        self._goto_x(x)

    cdef inline void cursor_position(self, unsigned short y, unsigned short x):
        """
        Moves the cursor to row n, column m. The values are 1-based, and default to 1 (top left corner) if omitted. 
        A sequence such as CSI ;5H is a synonym for CSI 1;5H as well as CSI 17;H is the same as CSI 17H and CSI 17;1H
        """
        self._goto_y(y)
        self._goto_x(x)
        self._current_line()

    cdef inline void erase_in_display(self, unsigned short alt):
        """
        Clears part of the screen. 
        If n is 0 (or missing), clear from cursor to end of screen. 
        If n is 1, clear from cursor to beginning of the screen. 
        If n is 2, clear entire screen (and moves cursor to upper left on DOS ANSI.SYS). 
        If n is 3, clear entire screen and delete all lines saved in the scrollback buffer 
        (this feature was added for xterm and is supported by other terminal applications).
        """
        cdef unsigned short start = 0, end = self._lines

        if alt == 0:
            start = self._y
        elif alt == 1:
            end = self._y
        elif alt == 2:
            self._goto_x(0)
            self._goto_y(0)
        elif alt == 3:
            pass  # Empty backbuffer history
        else:
            return

            # self._empty = bytes([32, 0, 0, 0, self._fg, self._bg, self._attr])
        for y in range(0, self._y):
            self._buffer[y] = self._new_line(self._cols)
        self._current_line()

    cdef inline void erase_in_line(self, unsigned short alt):
        """
        Erases part of the line. 
        If n is 0 (or missing), clear from cursor to the end of the line. 
        If n is 1, clear from cursor to beginning of the line. 
        If n is 2, clear entire line. 
        Cursor position does not change.
        """
        cdef unsigned short start = 0, end = self._cols
        cdef Glyph glyph

        if alt == 0:
            start = self._x
        elif alt == 1:
            end = self._x
        elif alt == 2:
            pass
        else:
            return

        glyph.units[0] = 32
        glyph.units[1] = 0
        glyph.units[2] = 0
        glyph.units[3] = 0

        for x in range(start, end):
            self._print(self._current, x, &glyph)

    cdef inline void scroll_up(self, unsigned short ups):
        """Scroll whole page up by n (default 1) lines. New lines are added at the bottom."""
        if ups < 1:
            ups = 1
        elif ups > self._lines:
            ups = self._lines

        for _ in range(ups):
            self._buffer.pop(0)
            self._buffer.append(self._new_line(self._cols))
        self._current_line()

    cdef inline void scroll_down(self, unsigned short downs):
        """Scroll whole page down by n (default 1) lines. New lines are added at the top."""
        if downs < 1:
            downs = 1
        elif downs > self._lines:
            downs = self._lines

        for _ in range(downs):
            self._buffer.pop(self._lines - 1)
            self._buffer.insert(0, self._new_line(self._cols))
        self._current_line()

    cdef inline void horizontal_vertical_position(self, unsigned short y, unsigned short x):
        """
        Same as CUP, but counts as a format effector function (like CR or LF) 
        rather than an editor function (like CUD or CNL). 
        This can lead to different handling in certain terminal modes.
        """
        self._goto_y(y)
        self._goto_x(x)
        self._current_line()

    cdef inline void aux_port(self, unsigned short alt):
        """Enable or disable aux serial port usually for local serial printer."""
        if alt == 5:
            pass
        elif alt == 4:
            pass

    cdef inline void device_status_report(self, unsigned short alt):
        """Reports the cursor position (CPR) by transmitting ESC[n;mR, where n is the row and m is the column.)"""
        pass

    cdef inline void save_cursor(self):
        """
        Saves the cursor position/state in SCO console mode. 
        In vertical split screen mode, instead used to set (as CSI n ; n s) or reset left and right margins.
        """
        pass

    cdef inline void restore_cursor(self):
        """Restores the cursor position/state in SCO console mode."""
        pass

    cdef inline void attr_reset(self):
        """Reset tile attributes."""
        self._fg = fgDEFAULT
        self._bg = bgDEFAULT
        self._attr = 0

    cdef inline void attr_bold_on(self):
        """Make glyphs bold."""
        if not self._attr & attrBOLD:
            self._attr ^= attrBOLD

    cdef inline void attr_dim_on(self):
        """Make glyphs dim."""
        if not self._attr & attrDIM:
            self._attr ^= attrDIM

    cdef inline void attr_italic_on(self):
        """Make glyphs italic."""
        if not self._attr & attrITALIC:
            self._attr ^= attrITALIC

    cdef inline void attr_underline_on(self):
        """Make glyphs underline."""
        if not self._attr & attrITALIC:
            self._attr ^= attrITALIC

    cdef inline void attr_blink_on(self):
        """Make tile blink."""
        if not self._attr & attrBLINK:
            self._attr ^= attrBLINK

    cdef inline void attr_invert_on(self):
        """Invert foreground and background on a tile."""
        if not self._attr & attrINVERT:
            self._attr ^= attrINVERT

    cdef inline void attr_strike_on(self):
        """Make glyphs strikethrough."""
        if not self._attr & attrSTRIKE:
            self._attr ^= attrSTRIKE

    cdef inline void attr_bold_dim_off(self):
        """Make glyphs non-bold and non-dim."""
        if self._attr & attrDIM:
            self._attr ^= attrDIM

    cdef inline void attr_italic_off(self):
        """Turn off italic for glyphs."""
        if self._attr & attrITALIC:
            self._attr ^= attrITALIC

    cdef inline void attr_underline_off(self):
        """Turn off underline for glyphs."""
        if self._attr & attrITALIC:
            self._attr ^= attrITALIC

    cdef inline void attr_blink_off(self):
        """Make tile stop blink."""
        if self._attr & attrBLINK:
            self._attr ^= attrBLINK

    cdef inline void attr_invert_off(self):
        """Reverse invert of tile foreground and background."""
        if self._attr & attrINVERT:
            self._attr ^= attrINVERT

    cdef inline void attr_strike_off(self):
        """Make glyphs not strikethrough."""
        if self._attr & attrSTRIKE:
            self._attr ^= attrSTRIKE

    cdef inline void color_foreground(self, unsigned char color):
        """Set foreground color."""
        self._fg = color

    cdef inline void color_background(self, unsigned char color):
        """Set background color."""
        self._bg = color

    cdef inline void key_home(self):
        """Home key pressed."""
        pass

    cdef inline void key_insert(self):
        """Insert key pressed."""
        pass

    cdef inline void key_delete(self):
        """Delete key pressed."""
        pass

    cdef inline void key_end(self):
        """End key pressed."""
        pass

    cdef inline void key_pgup(self):
        """PgUp key pressed."""
        pass

    cdef inline void key_pgdn(self):
        """PgDn key pressed."""
        pass

    cdef inline void key_f0(self):
        """F0 key pressed."""
        pass

    cdef inline void key_f1(self):
        """F1 key pressed."""
        pass

    cdef inline void key_f2(self):
        """F2 key pressed."""
        pass

    cdef inline void key_f3(self):
        """F3 key pressed."""
        pass

    cdef inline void key_f4(self):
        """F4 key pressed."""
        pass

    cdef inline void key_f5(self):
        """F5 key pressed."""
        pass

    cdef inline void key_f6(self):
        """F6 key pressed."""
        pass

    cdef inline void key_f7(self):
        """F7 key pressed."""
        pass

    cdef inline void key_f8(self):
        """F8 key pressed."""
        pass

    cdef inline void key_f9(self):
        """F9 key pressed."""
        pass

    cdef inline void key_f10(self):
        """F10 key pressed."""
        pass

    cdef inline void key_f11(self):
        """F11 key pressed."""
        pass

    cdef inline void key_f12(self):
        """F12 key pressed."""
        pass

    cdef inline void key_f13(self):
        """F13 key pressed."""
        pass

    cdef inline void key_f14(self):
        """F14 key pressed."""
        pass

    cdef inline void key_f15(self):
        """F15 key pressed."""
        pass

    cdef inline void key_f16(self):
        """F16 key pressed."""
        pass

    cdef inline void key_f17(self):
        """F17 key pressed."""
        pass

    cdef inline void key_f18(self):
        """F18 key pressed."""
        pass

    cdef inline void key_f19(self):
        """F19 key pressed."""
        pass

    cdef inline void key_f20(self):
        """F20 key pressed."""
        pass

    cdef inline void short_command(self, unsigned short keycode, bint meta, bint ctrl, bint alt, bint shift):
        """Short command."""
        pass


cdef class Stream(Screen):
    """Stream handler that processes whatever it's fed."""

    def __init__(self, cols: int = 80, lines: int = 24):
        Screen.__init__(self, cols, lines)

    def _display(self) -> None:
        """Extract all modified buffer data."""
        for y in range(self._lines):
            if self._modified[y].updated:
                yield y + 1, self._modified[y].begin + 1, self._modified[y].end + 1, \
                      self._buffer[y].data[self._modified[y].begin * 7:self._modified[y].end * 7]

    cpdef _feed(self, data: bytes):
        """Process input to the terminal."""
        cdef unsigned char byte = 0, rest = 0
        cdef Glyph glyph
        cdef ByteIterator biter = ByteIterator(data)

        while not biter.end or rest:
            if rest:
                byte = rest
                rest = 0
            else:
                byte = biter.next()

            if self.is_control(byte):
                self._control_characters(byte, biter)
            elif self.is_utf8(byte):
                if self._utf8_characters(byte, biter, &glyph):
                    self.print_glyph(&glyph)
            else:
                pass


    cdef inline bint is_printable(self, unsigned char byte) nogil:
        """Is byte a printable ASCII character?"""
        return 0x20 <= byte <= 0x7E

    cdef inline bint is_control(self, unsigned char byte) nogil:
        """Is byte an ASCII control character?"""
        return 0x00 <= byte <= 0x1F or byte == 0x7F

    cdef inline bint is_utf8(self, unsigned char byte) nogil:
        """Is byte an UTF-8 code unit?"""
        return 0x20 <= byte <= 0x7E or byte >> 6 == 2 or byte >> 5 == 6 or byte >> 4 == 14 or byte >> 3 == 30

    cdef inline bint _utf8_characters(self, unsigned char byte, ByteIterator iterator, Glyph *glyph) nogil:
        """Process a UTF-8 character and returns false on failure."""
        cdef unsigned char one = 0, two = 0, three = 0, four = 0

        if byte & 0b10000000 == 0:  # One byte character
            one = byte

            if not (0x20 <= byte <= 0x7E):  # Printable?
                return False
            else:
                glyph.units[0] = one
                glyph.units[1] = two
                glyph.units[2] = three
                glyph.units[3] = four

        elif byte >> 5 == 6:  # Two byte character
            one = byte
            two = iterator.next()

            if two >> 6 != 2:  # True code units?
                return False
            else:
                glyph.units[0] = one
                glyph.units[1] = two
                glyph.units[2] = three
                glyph.units[3] = four

        elif byte >> 4 == 14:  # Three byte character
            one = byte
            two = iterator.next()
            three = iterator.next()

            if two >> 6 != 2 or three >> 6 != 2:  # True code units?
                return False
            else:
                glyph.units[0] = one
                glyph.units[1] = two
                glyph.units[2] = three
                glyph.units[3] = four

        elif byte >> 3 == 30:  # Four byte character
            one = byte
            two = iterator.next()
            three = iterator.next()
            four = iterator.next()

            if two >> 6 != 2 or three >> 6 != 2 or four >> 6 != 2:  # True code units?
                return False
            else:
                glyph.units[0] = one
                glyph.units[1] = two
                glyph.units[2] = three
                glyph.units[3] = four

        else:
            return False

        return True

    cdef inline unsigned char _control_characters(self, unsigned char byte, ByteIterator iterator):
        """Process a control character."""
        cdef unsigned char rest = 0

        if byte == ctrlBEL:
            self.bell()
        elif byte == ctrlBS:
            self.backspace()
        elif byte == ctrlHT:
            self.tab()
        elif byte == ctrlLF:
            self.line_feed()
        elif byte == ctrlFF:
            self.form_feed()
        elif byte == ctrlCR:
            self.carriage_return()
        elif byte == ctrlESC:
            rest = self._escape_sequence(iterator)

        return rest

    cdef inline unsigned char _escape_sequence(self, ByteIterator iterator):
        """Process an escape sequence."""
        cdef unsigned char byte = iterator.next(), rest = 0

        if not 0x40 <= byte <= 0x5F:
            self.escape()
            rest = byte
        elif byte == escSS2:
            pass
        elif byte == escSS3:
            pass
        elif byte == escDCS:
            pass
        elif byte in (escCSI, escCSI1):
            rest = self._csi_sequence(iterator)
        elif byte in (escST, escST1):
            pass
        elif byte in (escOSC, escOSC1):
            pass
        elif byte == escPM:
            pass
        elif byte == escAPC:
            pass

        return rest

    cdef inline unsigned char _csi_sequence(self, ByteIterator iterator):
        """Parse CSI sequence."""
        cdef unsigned char byte = 0, final_byte = 0
        cdef unsigned int value = 0, idx = 1, vlen = 16, plen = 0
        cdef unsigned int[10] params = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        cdef unsigned char[16] param_text = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        cdef unsigned char[16] inter_text = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

        if not iterator.end:
            byte = iterator.next()

        if 0x30 <= byte <= 0x3F:  # Scan parameter bytes
            if 0x30 <= byte <= 0x3A:  # Parameter variables
                value = byte - 0x30
                while not iterator.end and plen < 10:
                    byte = iterator.next()
                    if 0x30 <= byte <= 0x3A:
                        value = (value * 10) + (byte - 0x30)
                    elif byte == 0x3B:
                        params[plen] = value
                        plen += 1
                        value = 0
                    else:
                        params[plen] = value
                        plen += 1
                        value = 0
                        break
            else:  # Parameter string
                param_text[0] = byte
                while not iterator.end and idx < vlen:
                    byte = iterator.next()
                    if 0x30 <= byte <= 0x3F:
                        param_text[idx] = byte
                        idx += 1
                    else:
                        param_text[idx] = 0
                        break

        if 0x20 <= byte <= 0x2F:  # Scan intermediate bytes
            idx = 1
            inter_text[0] = byte
            while not iterator.end and idx < vlen:
                byte = iterator.next()
                if 0x20 <= byte <= 0x2F:
                    inter_text[idx] = byte
                    idx += 1
                else:
                    inter_text[idx] = 0
                    break

        if 0x40 <= byte <= 0x7E:  # Scan final byte
            final_byte = byte
        else:
            return byte

        if final_byte == csiCUU:  # Cursor Up
            self.cursor_up(params[0] if params[0] else 1)
        elif final_byte == csiCUD:  # Cursor Down
            self.cursor_down(params[0] if params[0] else 1)
        elif final_byte == csiCUF:  # Cursor Forward
            self.cursor_forward(params[0] if params[0] else 1)
        elif final_byte == csiCUB:  # Cursor Back
            self.cursor_back(params[0] if params[0] else 1)
        elif final_byte == csiCNL:  # Cursor Next Line
            self.cursor_next_line(params[0] if params[0] else 1)
        elif final_byte == csiCPL:  # Cursor Previous Line
            self.cursor_previous_line(params[0] if params[0] else 1)
        elif final_byte == csiCHA:  # Cursor Horizontal Absolute
            self.cursor_horizontal_absolute(params[0] if params[0] else 1)
        elif final_byte == csiCUP:  # Cursor Position
            self.cursor_position(params[0] if params[0] else 1, params[1] if params[1] else 1)
        elif final_byte == csiED:  # Erase in Display
            self.erase_in_display(params[0])
        elif final_byte == csiEL:  # Erase in Line
            self.erase_in_line(params[0])
        elif final_byte == csiSU:  # Scroll Up
            self.scroll_up(params[0] if params[0] else 1)
        elif final_byte == csiCSD:  # Scroll Down
            self.scroll_down(params[0] if params[0] else 1)
        elif final_byte == csiHVP:  # Horizontal Vertical Position
            self.horizontal_vertical_position(params[0] if params[0] else 1, params[1] if params[1] else 1)
        elif final_byte == csiSGR:  # Select Graphic Rendition
            self._sgr_parameters(params[0])
        elif final_byte == csiAUX:  # AUX Port
            self.aux_port(params[0])
        elif final_byte == csiDSR:  # Device Status Report
            self.device_status_report(params[0])
        elif final_byte == csiVT:  # VT Sequences
            if plen == 1:
                self._vt_sequence(params[0])
            elif plen == 2:
                self._vt_modifer(params[0], params[1])
        elif final_byte == cisSCP:  #  Save Current Cursor Position
            self.save_cursor()
        elif final_byte == csiRCP:  #  Restore Saved Cursor Position
            self.restore_cursor()

        return 0

    cdef inline void _sgr_parameters(self, unsigned char param):
        """Select graphic rendition."""

        if param == sgrRESET:  # Reset or normal
            self.attr_reset()
        elif param == sgrBOLD_ON:  # Bold or increased intensity
            self.attr_bold_on()
        elif param == sgrDIM_ON:  # Faint, decreased intensity, or dim
            self.attr_dim_on()
        elif param == sgrITALIC_ON:  # Italic
            self.attr_italic_on()
        elif param == sgrUNDERLINE_ON:  # Underline
            self.attr_underline_on()
        elif param == sgrBLINK_ON:  # Slow blink
            self.attr_blink_on()
        elif param == sgrINVERT_ON:  # Reverse video or invert
            self.attr_invert_on()
        elif param == sgrSTRIKE_ON:  # Crossed-out, or strike
            self.attr_strike_on()
        elif param == sgrBOLD_OFF:  # Normal intensity
            self.attr_bold_dim_off()
        elif param == sgrITALIC_OFF:  # Neither italic, nor blackletter
            self.attr_italic_off()
        elif param == sgrUNDERLINE_OFF:  # Not underlined
            self.attr_underline_off()
        elif param == sgrBLINK_OFF:  # Not blinking
            self.attr_blink_off()
        elif param == sgrINVERT_OFF:  # Not reversed
            self.attr_invert_off()
        elif param == sgrSTRIKE_OFF:  # Not crossed out
            self.attr_strike_off()
        elif 30 <= param <= 37 or param == 39 or 90 <= param <= 97:  # Foreground
            self.color_foreground(param)
        elif 40 <= param <= 47 or param == 49 or 100 <= param <= 107:  # Background
            self.color_background(param)

    cdef inline void _vt_sequence(self, unsigned int keycode):
        """Key codes for special keys."""

        if keycode == vtHome:
            self.key_home()
        elif keycode == vtInsert:
            self.key_insert()
        elif keycode == vtDelete:
            self.key_delete()
        elif keycode == vtEnd:
            self.key_end()
        elif keycode == vtPgUp:
            self.key_pgup()
        elif keycode == vtPgDn:
            self.key_pgdn()
        elif keycode == vtHome2:
            self.key_home()
        elif keycode == vtEnd2:
            self.key_end()
        elif keycode == vtF0:
            self.key_f0()
        elif keycode == vtF1:
            self.key_f1()
        elif keycode == vtF2:
            self.key_f2()
        elif keycode == vtF3:
            self.key_f3()
        elif keycode == vtF4:
            self.key_f4()
        elif keycode == vtF5:
            self.key_f5()
        elif keycode == vtF6:
            self.key_f6()
        elif keycode == vtF7:
            self.key_f7()
        elif keycode == vtF8:
            self.key_f8()
        elif keycode == vtF9:
            self.key_f9()
        elif keycode == vtF10:
            self.key_f10()
        elif keycode == vtF11:
            self.key_f11()
        elif keycode == vtF12:
            self.key_f12()
        elif keycode == vtF13:
            self.key_f13()
        elif keycode == vtF14:
            self.key_f14()
        elif keycode == vtF15:
            self.key_f15()
        elif keycode == vtF16:
            self.key_f16()
        elif keycode == vtF17:
            self.key_f17()
        elif keycode == vtF18:
            self.key_f18()
        elif keycode == vtF19:
            self.key_f19()
        elif keycode == vtF20:
            self.key_f20()

    cdef inline void _vt_modifer(self, unsigned int keycode, unsigned int modifier):
        """Meta keys."""
        modifier -= 1
        self.short_command(keycode, modifier >> 3 & 1, modifier >> 2 & 1, modifier >> 1 & 1, modifier & 1)


class Terminal(Stream):
    def __init__(self, cols: int = 80, lines: int = 24):
        Stream.__init__(self, cols, lines)


def print_line(short y, short begin, short end, bytes data) -> bytearray:
    """Convert line of bytes into ANSI escape codes."""
    if len(data) != (end - begin) * 7:
        raise RuntimeWarning("Data length arbitrary.")

    cdef bytearray line = bytearray()
    cdef bytearray code = bytearray()
    cdef bytes glyph = None
    cdef bint is_wide_char = False

    cdef unsigned char fg_a = fgDEFAULT, fg_b = fgDEFAULT
    cdef unsigned char bg_a = bgDEFAULT, bg_b = bgDEFAULT
    cdef unsigned char attr_a = 0, attr_b = 0
    cdef unsigned char[9] attr = [0, 0, 0, 0, 0, 0, 0, 0, 0]
    cdef unsigned short glyph_len = 0

    cdef short jdx = 0

    for x in range(0, (end - begin) * 7, 7):
        if is_wide_char:  # Skip stub
            is_wide_char = False
            continue

        fg_a = data[x + 4]
        if fg_b != fg_a:
            fg_b = fg_a
            attr[0] = fg_b
        bg_a = data[x + 5]
        if bg_b != bg_a:
            bg_b = bg_a
            attr[1] = bg_b

        attr_a = data[x + 6]
        if attr_b & attrBOLD != attr_a & attrBOLD:
            attr[2] = sgrBOLD_ON if attr_a & attrBOLD == 1 else sgrBOLD_OFF
        if attr_b & attrDIM != attr_a & attrDIM:
            attr[3] = sgrDIM_ON if attr_a & attrDIM == 2 else sgrDIM_OFF
        if attr_b & attrITALIC != attr_a & attrITALIC:
            attr[4] = sgrITALIC_ON if attr_a & attrITALIC == 4 else sgrITALIC_OFF
        if attr_b & attrUNDER != attr_a & attrUNDER:
            attr[5] = sgrUNDERLINE_ON if attr_a & attrUNDER == 8 else sgrUNDERLINE_OFF
        if attr_b & attrSTRIKE != attr_a & attrSTRIKE:
            attr[6] = sgrSTRIKE_ON if attr_a & attrSTRIKE == 64 else sgrSTRIKE_OFF
        if attr_b & attrINVERT != attr_a & attrINVERT:
            attr[7] = sgrINVERT_ON if attr_a & attrINVERT == 32 else sgrINVERT_OFF
        if attr_b & attrBLINK != attr_a & attrBLINK:
            attr[8] = sgrBLINK_ON if attr_a & attrBLINK == 16 else sgrBLINK_OFF
        attr_b = attr_a

        jdx = 0
        while jdx < 9:
            if attr[jdx]:
                code += str(attr[jdx]).encode() + b";"
                attr[jdx] = 0
            jdx += 1

        if code:
            line += b"\x1b[" + code[:-1] + b"m"
            code.clear()

        glyph_len = utf8_len(data[x])
        if glyph_len > 0:
            glyph = data[x:x + glyph_len]
            is_wide_char = east_asian_width(glyph.decode()) in "WF"
            line += glyph

    line += b"\x1b[0m"
    return line
