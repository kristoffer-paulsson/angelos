# cython: language_level=3
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

cdef enum TileAttributeCodes:
    attrBOLD = 1 << 0  # Flag for bold bit
    attrDIM = 1 << 1  # Flag for dim bit
    attrITALIC = 1 << 2  # Flag for italic bit
    attrUNDER = 1 << 3  # Flag for underscore bit
    attrBLINK = 1 << 4  # Flag for blink bit
    attrREVERSE = 1 << 5  # Flag for invert bit
    attrSTRIKE = 1 << 6  # Flag for strike bit


ctypedef struct Tile:
    unsigned char[4] glyph
    unsigned char fg
    unsigned char bg
    unsigned char attr

ctypedef Tile *TilePtr
ctypedef Tile[:] TileView


cdef unsigned char TILE_SIZE = sizeof(Tile)
TEMPLATE_NONE = bytes(b"\x00" * TILE_SIZE)


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


cdef class Screen:

    cdef unsigned short _cols;
    cdef unsigned short _lines;
    cdef unsigned short _x;
    cdef unsigned short _y;

    cdef unsigned char _on;
    cdef unsigned char _off;

    def __init__(self, cols: int = 80, lines: int = 24):
        self._x = 0
        self._y = 0
        self._cols = cols
        self._lines = lines

        self._empty = self._tileplate()
        self._buffer = list()

        for _ in range(lines):
            self._buffer.append(self._new_line(cols, self._empty))

    @property
    def x(self) -> int:
        """Cursor X position."""
        return self._x

    @property
    def y(self) -> int:
        """Cursor Y position."""
        return self._y

    @property
    def columns(self) -> int:
        """Width of the PTY."""
        return self._cols

    @property
    def lines(self) -> int:
        """Height of the PTY."""
        return self._lines

    def _tileplate(
            self,
            bytes glyph = b" \x00\x00\x00", unsigned char fg = fgDEFAULT,
            unsigned char bg = bgDEFAULT, unsigned char attr = 0x00
        ) -> bytes:
        """Templates a tile from input data and returns it as bytes."""
        cdef TilePtr tile
        data = bytes(sizeof(Tile))
        tile = <Tile*>data

        tile.glyph[:] = glyph[:4]
        tile.fg = fg
        tile.bg = bg
        tile.attr = attr

        return data

    def _new_line(self, unsigned int cols) -> tuple:
        """Create a new line for the buffer, returns a tuple of bytes data and cython Tile memoryview."""
        cdef TilePtr tile_array
        data = bytes(cols*self._empty)
        tile_array = <Tile*>data
        view = <Tile[:cols]>tile_array

        return data, view

    def _resize_line(self, unsigned int y, unsigned int cols) -> tuple:
        """Resizes an existing line buffer preserving data."""
        cdef TilePtr tile_array
        data, view = self._buffer[y]
        cdef size = len(view)

        if size > cols:
            data = data[:cols]
            tile_array = <Tile*>data
            view = view = <Tile[:cols]>tile_array
        elif size < cols:
            data = data + bytes((cols-size)*self._empty)
            tile_array = <Tile*>data
            view = view = <Tile[:cols]>tile_array

        return data, view


    cdef inline bint print_glyph(self, bytes glyph):
        """Print glyph to console."""
        pass

    cdef inline bint bell(self):
        """Executes the BEL control character."""
        pass

    cdef inline bint backspace(self):
        """Executes the BS control character."""
        pass

    cdef inline bint tab(self):
        """Executes the HT control character."""
        pass

    cdef inline bint line_feed(self):
        """Executes the LF control character."""
        pass

    cdef inline bint form_feed(self):
        """Executes the FF control character."""
        pass

    cdef inline bint carriage_return(self):
        """Executes the CR control character."""
        pass

    cdef inline bint escape(self):
        """Executes the ESC control character."""
        pass

    cdef inline bint cursor_up(self, unsigned short steps):
        """
        Moves the cursor n (default 1) cells up. 
        If the cursor is already at the edge of the screen, this has no effect.
        """
        pass

    cdef inline bint cursor_down(self, unsigned short steps):
        """
        Moves the cursor n (default 1) cells down. 
        If the cursor is already at the edge of the screen, this has no effect.
        """
        pass

    cdef inline bint cursor_forward(self, unsigned short steps):
        """
        Moves the cursor n (default 1) cells forward. 
        If the cursor is already at the edge of the screen, this has no effect.
        """
        pass

    cdef inline bint cursor_back(self, unsigned short steps):
        """
        Moves the cursor n (default 1) cells previous. 
        If the cursor is already at the edge of the screen, this has no effect.
        """
        pass

    cdef inline bint cursor_next_line(self, unsigned short downs):
        """Moves cursor to beginning of the line n (default 1) lines down."""
        pass

    cdef inline bint cursor_previous_line(self, unsigned short ups):
        """Moves cursor to beginning of the line n (default 1) lines up."""
        pass

    cdef inline bint cursor_horizontal_absolute(self, unsigned short y):
        """Moves the cursor to column n (default 1)."""
        pass

    cdef inline bint cursor_position(self, unsigned short y, unsigned short x):
        """
        Moves the cursor to row n, column m. The values are 1-based, and default to 1 (top left corner) if omitted. 
        A sequence such as CSI ;5H is a synonym for CSI 1;5H as well as CSI 17;H is the same as CSI 17H and CSI 17;1H
        """
        pass

    cdef inline bint erase_in_display(self, unsigned short alt):
        """
        Clears part of the screen. If n is 0 (or missing), clear from cursor to end of screen. 
        If n is 1, clear from cursor to beginning of the screen. 
        If n is 2, clear entire screen (and moves cursor to upper left on DOS ANSI.SYS). 
        If n is 3, clear entire screen and delete all lines saved in the scrollback buffer 
        (this feature was added for xterm and is supported by other terminal applications).
        """
        pass

    cdef inline bint erase_in_line(self, unsigned short alt):
        """
        Erases part of the line. If n is 0 (or missing), clear from cursor to the end of the line. 
        If n is 1, clear from cursor to beginning of the line. If n is 2, clear entire line. 
        Cursor position does not change.
        """
        pass

    cdef inline bint scroll_up(self, unsigned short ups):
        """Scroll whole page up by n (default 1) lines. New lines are added at the bottom."""
        pass

    cdef inline bint scroll_down(self, unsigned short downs):
        """Scroll whole page down by n (default 1) lines. New lines are added at the top."""
        pass

    cdef inline bint horizontal_vertical_position(self, unsigned short y, unsigned short x):
        """
        Same as CUP, but counts as a format effector function (like CR or LF) 
        rather than an editor function (like CUD or CNL). 
        This can lead to different handling in certain terminal modes.
        """
        pass

    cdef inline bint aux_port(self, unsigned short alt):
        """Enable or disable aux serial port usually for local serial printer."""
        pass

    cdef inline bint device_status_report(self, unsigned short alt):
        """Reports the cursor position (CPR) by transmitting ESC[n;mR, where n is the row and m is the column.)"""
        pass

    cdef inline bint save_cursor(self):
        """
        Saves the cursor position/state in SCO console mode. 
        In vertical split screen mode, instead used to set (as CSI n ; n s) or reset left and right margins.
        """
        pass

    cdef inline bint restore_cursor(self):
        """Restores the cursor position/state in SCO console mode."""
        pass

    cdef inline bint attr_reset(self):
        """Reset tile attributes."""
        pass

    cdef inline bint attr_bold_on(self):
        """Make glyphs bold."""
        pass

    cdef inline bint attr_dim_on(self):
        """Make glyphs dim."""
        pass

    cdef inline bint attr_italic_on(self):
        """Make glyphs italic."""
        pass

    cdef inline bint attr_underline_on(self):
        """Make glyphs underline."""
        pass

    cdef inline bint attr_blink_on(self):
        """Make tile blink."""
        pass

    cdef inline bint attr_invert_on(self):
        """Invert foreground and background on a tile."""
        pass

    cdef inline bint attr_strike_on(self):
        """Make glyphs strikethrough."""
        pass

    cdef inline bint attr_bold_dim_off(self):
        """Make glyphs non-bold and non-dim."""
        pass

    cdef inline bint attr_italic_off(self):
        """Turn off italic for glyphs."""
        pass

    cdef inline bint attr_underline_off(self):
        """Turn off underline for glyphs."""
        pass

    cdef inline bint attr_blink_off(self):
        """Make tile stop blink."""
        pass

    cdef inline bint attr_invert_off(self):
        """Reverse invert of tile foreground and background."""
        pass

    cdef inline bint attr_strike_off(self):
        """Make glyphs not strikethrough."""
        pass

    cdef inline bint color_foreground(self, unsigned char color):
        """Set foreground."""
        pass

    cdef inline bint color_background(self, unsigned char color):
        """Set background."""
        pass

    cdef inline bint key_home(self):
        """Home key pressed."""
        pass

    cdef inline bint key_insert(self):
        """Insert key pressed."""
        pass

    cdef inline bint key_delete(self):
        """Delete key pressed."""
        pass

    cdef inline bint key_end(self):
        """End key pressed."""
        pass

    cdef inline bint key_pgup(self):
        """PgUp key pressed."""
        pass

    cdef inline bint key_pgdn(self):
        """PgDn key pressed."""
        pass

    cdef inline bint key_f0(self):
        """F0 key pressed."""
        pass

    cdef inline bint key_f1(self):
        """F1 key pressed."""
        pass

    cdef inline bint key_f2(self):
        """F2 key pressed."""
        pass

    cdef inline bint key_f3(self):
        """F3 key pressed."""
        pass

    cdef inline bint key_f4(self):
        """F4 key pressed."""
        pass

    cdef inline bint key_f5(self):
        """F5 key pressed."""
        pass

    cdef inline bint key_f6(self):
        """F6 key pressed."""
        pass

    cdef inline bint key_f7(self):
        """F7 key pressed."""
        pass

    cdef inline bint key_f8(self):
        """F8 key pressed."""
        pass

    cdef inline bint key_f9(self):
        """F9 key pressed."""
        pass

    cdef inline bint key_f10(self):
        """F10 key pressed."""
        pass

    cdef inline bint key_f11(self):
        """F11 key pressed."""
        pass

    cdef inline bint key_f12(self):
        """F12 key pressed."""
        pass

    cdef inline bint key_f13(self):
        """F13 key pressed."""
        pass

    cdef inline bint key_f14(self):
        """F14 key pressed."""
        pass

    cdef inline bint key_f15(self):
        """F15 key pressed."""
        pass

    cdef inline bint key_f16(self):
        """F16 key pressed."""
        pass

    cdef inline bint key_f17(self):
        """F17 key pressed."""
        pass

    cdef inline bint key_f18(self):
        """F18 key pressed."""
        pass

    cdef inline bint key_f19(self):
        """F19 key pressed."""
        pass

    cdef inline bint key_f20(self):
        """F20 key pressed."""
        pass


cdef class ByteIterator:
    """Bytes object iterator with close to C speed."""

    cdef readonly bint empty;
    cdef readonly unsigned long index, length;

    def __init__(self, data: bytes):
        cdef unsigned char *byte_array
        self._data = data
        self.index = 0
        self.length = len(data)
        byte_array = <unsigned char*>data
        self._view = <unsigned char[:self.length]>byte_array
        self.empty = not bool(self.length)

    cdef inline unsigned char next(self):
        """Next byte in stream. If empty returns a 0."""
        cdef unsigned char byte = 0
        if not self.empty:
            byte = self._view[self.index]
            self.index += 1
            if self.index == self.length:
                self.empty = True
        return byte


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
    escSCI = 0x9B  # Control Sequence Introducer
    escST = 0x9C  # String Terminator
    escOSC = 0x9D  # Operating System Command
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


cdef class Stream:
    """TTY Stream handler that processes whatever it's fed."""

    def __init__(self, screen: Screen):
        self._screen = screen

    @property
    def screen(self) -> Screen:
        return self._screen

    def feed(self, data: bytes):
        """Process input to the terminal."""
        cdef unsigned char byte = 0, rest = 0
        cdef unsigned char *glyph
        biter = ByteIterator(data)
        utf8 = bytes(4)
        glyph = <unsigned char*>utf8

        while not biter.empty or rest:
            if rest:
                byte = rest
                rest = 0
            else:
                byte = biter.next()

            if self.is_control(byte):
                self._control_characters(byte, biter)
            elif self.is_utf8(byte):
                if self._utf8_characters(byte, biter, glyph):
                    self._screen.print_glyph(utf8)
            else:
                pass

    cdef inline bint is_printable(self, unsigned char byte):
        """Is byte a printable ASCII character?"""
        return 0x20 <= byte <= 0x7E

    cdef inline bint is_control(self, unsigned char byte):
        """Is byte an ASCII control character?"""
        return 0x00 <= byte <= 0x1F or byte == 0x7F

    cdef inline bint is_utf8(self, unsigned char byte):
        """Is byte an UTF-8 code unit?"""
        return byte >> 6 == 2 or byte >> 5 == 6 or byte >> 4 == 14 or byte >> 3 == 30

    cdef inline bint _utf8_characters(self, unsigned char byte, ByteIterator iterator, unsigned char *glyph):
        """Process a UTF-8 character and returns false on failure."""
        cdef unsigned char one = 0, two = 0, three = 0, four = 0

        if byte & 0b10000000 == 0:  # One byte character
            one = byte % 0b01111111

            if not (0x20 <= byte <= 0x7E):  # Printable?
                return False
            else:
                glyph[0] = one
                glyph[1] = two
                glyph[2] = three
                glyph[3] = four

        elif byte >> 5 == 6:  # Two byte character
            one = byte & 0b00011111
            two = iterator.next()

            if two >> 6 != 2:  # True code units?
                return False
            else:
                glyph[0] = one
                glyph[1] = two & 0b00111111
                glyph[2] = three
                glyph[3] = four

        elif byte >> 4 == 14:  # Three byte character
            one = byte & 0b00001111
            two = iterator.next()
            three = iterator.next()

            if two >> 6 != 2 or three >> 6 != 2:  # True code units?
                return False
            else:
                glyph[0] = one
                glyph[1] = two & 0b00111111
                glyph[2] = three & 0b00111111
                glyph[3] = four

        elif byte >> 3 == 30:  # Four byte character
            one = byte & 0b00000111
            two = iterator.next()
            three = iterator.next()
            four = iterator.next()

            if two >> 6 != 2 or three >> 6 != 2 or four >> 6 != 2:  # True code units?
                return False
            else:
                glyph[0] = one
                glyph[1] = two & 0b00111111
                glyph[2] = three & 0b00111111
                glyph[3] = four & 0b00111111

        else:
            return False

        return True

    cdef inline unsigned char _control_characters(self, unsigned char byte, ByteIterator iterator):
        """Process a control character."""
        cdef unsigned char rest = 0

        if byte == ctrlBEL:
            self._screen.bell()
        elif byte == ctrlBS:
            self._screen.backspace()
        elif byte == ctrlHT:
            self._screen.tab()
        elif byte == ctrlLF:
            self._screen.line_feed()
        elif byte == ctrlFF:
            self._screen.form_feed()
        elif byte == ctrlCR:
            self._screen.carriage_return()
        elif byte == ctrlESC:
            rest = self._escape_sequence(iterator)

        return rest

    cdef inline unsigned char _escape_sequence(self, ByteIterator iterator):
        """Process an escape sequence."""
        cdef unsigned char byte = iterator.next(), rest = 0

        if not 0x40 <= byte <= 0x5F:
            self._screen.escape()
            rest = byte
        elif byte == escSS2:
            pass
        elif byte == escSS3:
            pass
        elif byte == escDCS:
            pass
        elif byte == escSCI:
            rest = self._csi_sequence(iterator)
        elif byte == escST:
            pass
        elif byte == escOSC:
            pass
        elif byte == escPM:
            pass
        elif byte == escAPC:
            pass

        return rest

    cdef inline unsigned char _csi_sequence(self, ByteIterator iterator):
        """Parse CSI sequence."""
        cdef unsigned char byte = 0, final_byte
        cdef unsigned int value, idx = 1, vlen = 32,
        cdef unsigned int params[10], plen = 0
        param_text = bytearray(vlen)
        inter_text = bytearray(vlen)

        if not iterator.empty:
            byte = iterator.next()

        if 0x30 <= byte <= 0x3F:  # Scan parameter bytes
            if 0x30 <= byte <= 0x3A:  # Parameter variables
                value = byte - 0x30
                while not iterator.empty and plen < 10:
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
                while not iterator.empty and idx < vlen:
                    byte = iterator.next()
                    if 0x30 <= byte <= 0x3F:
                        param_text[idx] = byte
                        idx += 1
                    else:
                        param_text = param_text.rstrip()
                        break

        if 0x20 <= byte <= 0x2F:  # Scan intermediate bytes
            idx = 1
            inter_text[0] = byte
            while not iterator.empty and idx < vlen:
                byte = iterator.next()
                if 0x20 <= byte <= 0x2F:
                    inter_text[idx] = byte
                    idx += 1
                else:
                    inter_text = inter_text.rstrip()
                    break

        if 0x40 <= byte <= 0x7E:  # Scan final byte
            final_byte = byte
        else:
            return byte

        if final_byte == csiCUU:  # Cursor Up
            self._screen.cursor_up(params[0] if params[0] else 1)
        elif final_byte == csiCUD:  # Cursor Down
            self._screen.cursor_down(params[0] if params[0] else 1)
        elif final_byte == csiCUF:  # Cursor Forward
            self._screen.cursor_forward(params[0] if params[0] else 1)
        elif final_byte == csiCUB:  # Cursor Back
            self._screen.cursor_back(params[0] if params[0] else 1)
        elif final_byte == csiCNL:  # Cursor Next Line
            self._screen.cursor_next_line(params[0] if params[0] else 1)
        elif final_byte == csiCPL:  # Cursor Previous Line
            self._screen.cursor_previous_line(params[0] if params[0] else 1)
        elif final_byte == csiCHA: # Cursor Horizontal Absolute
            self._screen.cursor_horizontal_absolute(params[0] if params[0] else 1)
        elif final_byte == csiCUP:  # Cursor Position
            self._screen.cursor_position(params[0] if params[0] else 1, params[1] if params[1] else 1)
        elif final_byte == csiED:  # Erase in Display
            self._screen.erase_in_display(params[0])
        elif final_byte == csiEL:  # Erase in Line
            self._screen.erase_in_line(params[0])
        elif final_byte == csiSU:  # Scroll Up
            self._screen.scroll_up(params[0] if params[0] else 1)
        elif final_byte == csiCSD:  # Scroll Down
            self._screen.scroll_down(params[0] if params[0] else 1)
        elif final_byte == csiHVP:  # Horizontal Vertical Position
            self._screen.horizontal_vertical_position(params[0] if params[0] else 1, params[1] if params[1] else 1)
        elif final_byte == csiSGR:  # Select Graphic Rendition
            self._sgr_parameters(params[0])
        elif final_byte == csiAUX: # AUX Port
            self._screen.aux_port(params[0])
        elif final_byte == csiDSR: # Device Status Report
            self._screen.device_status_report(params[0])
        elif final_byte == csiVT:  # VT Sequences
            if plen == 1:
                self._vt_sequence(params[0])
            elif plen == 2:
                self._vt_modifer(params[0], params[1])
        elif final_byte == cisSCP:  #  Save Current Cursor Position
            self._screen.save_cursor()
        elif final_byte == csiRCP:  #  Restore Saved Cursor Position
            self._screen.restore_cursor()

        return 0

    cdef inline bint _sgr_parameters(self, unsigned int param):
        """Select graphic rendition."""
        if param == sgrRESET:  # Reset or normal
            self._screen.attr_reset()
        elif param == sgrBOLD_ON:  # Bold or increased intensity
            self._screen.attr_bold_on()
        elif param == sgrDIM_ON:  # Faint, decreased intensity, or dim
            self._screen.attr_dim_on()
        elif param == sgrITALIC_ON:  # Italic
            self._screen.attr_italic_on()
        elif param == sgrUNDERLINE_ON:  # Underline
            self._screen.attr_underline_on()
        elif param == sgrBLINK_ON:  # Slow blink
            self._screen.attr_blink_on()
        elif param == sgrINVERT_ON:  # Reverse video or invert
            self._screen.attr_invert_on()
        elif param == sgrSTRIKE_ON:  # Crossed-out, or strike
            self._screen.attr_strike_on()
        elif param == sgrBOLD_OFF:  # Normal intensity
            self._screen.attr_bold_dim_off()
        elif param == sgrITALIC_OFF:  # Neither italic, nor blackletter
            self._screen.attr_italic_off()
        elif param == sgrUNDERLINE_OFF:  # Not underlined
            self._screen.attr_underline_off()
        elif param == sgrBLINK_OFF:  # Not blinking
            self._screen.attr_blink_off()
        elif param == sgrINVERT_OFF:  # Not reversed
            self._screen.attr_invert_off()
        elif param == sgrSTRIKE_OFF:  # Not crossed out
            self._screen.attr_strike_off()
        elif 30 <= param <= 37 or param == 39 or 90 <= param <= 97:  # Foreground
            self._screen.color_foreground(param)
        elif 40 <= param <= 47 or param == 49 or 100 <= param <= 107:  # Background
            self._screen.color_background(param)

    cdef inline bint _vt_sequence(self, unsigned int keycode):
        """Key codes for special keys."""
        if keycode == vtHome:
            self._screen.key_home()
        elif keycode == vtInsert:
            self._screen.key_insert()
        elif keycode == vtDelete:
            self._screen.key_delete()
        elif keycode == vtEnd:
            self._screen.key_end()
        elif keycode == vtPgUp:
            self._screen.key_pgup()
        elif keycode == vtPgDn:
            self._screen.key_pgdn()
        elif keycode == vtHome2:
            self._screen.key_home()
        elif keycode == vtEnd2:
            self._screen.key_end()
        elif keycode == vtF0:
            self._screen.key_f0()
        elif keycode == vtF1:
            self._screen.key_f1()
        elif keycode == vtF2:
            self._screen.key_f2()
        elif keycode == vtF3:
            self._screen.key_f3()
        elif keycode == vtF4:
            self._screen.key_f4()
        elif keycode == vtF5:
            self._screen.key_f5()
        elif keycode == vtF6:
            self._screen.key_f6()
        elif keycode == vtF7:
            self._screen.key_f7()
        elif keycode == vtF8:
            self._screen.key_f8()
        elif keycode == vtF9:
            self._screen.key_f9()
        elif keycode == vtF10:
            self._screen.key_f10()
        elif keycode == vtF11:
            self._screen.key_f11()
        elif keycode == vtF12:
            self._screen.key_f12()
        elif keycode == vtF13:
            self._screen.key_f13()
        elif keycode == vtF14:
            self._screen.key_f14()
        elif keycode == vtF15:
            self._screen.key_f15()
        elif keycode == vtF16:
            self._screen.key_f16()
        elif keycode == vtF17:
            self._screen.key_f17()
        elif keycode == vtF18:
            self._screen.key_f18()
        elif keycode == vtF19:
            self._screen.key_f19()
        elif keycode == vtF20:
            self._screen.key_f20()

    cdef inline bint _vt_modifer(self, unsigned int keycode, unsigned int modifier):
        """Meta keys."""
        pass

cdef class Terminal:
    pass
