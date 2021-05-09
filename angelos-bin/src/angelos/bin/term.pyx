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
    csiCUU = ord(b"A")  # Cursor Up
    csiCUD = ord(b"B")  # Cursor Down
    csiCUF = ord(b"C")  # Cursor Forward
    csiCUB = ord(b"D")  # Cursor Back
    csiCNL = ord(b"E")  # Cursor Next Line
    csiCPL = ord(b"F")  # Cursor Previous Line
    csiCHA = ord(b"G")  # Cursor Horizontal Absolute
    csiCUP = ord(b"H")  # Cursor Position
    csiED = ord(b"J")  # Erase in Display
    csiEL = ord(b"K")  # Erase in Line
    csiSU = ord(b"S")  # Scroll Up
    csiCSD = ord(b"T")  # Scroll Down
    csiHVP = ord(b"f")  # Horizontal Vertical Position
    csiSGR = ord(b"m")  # Select Graphic Rendition
    csiAUX = ord(b"i")  # AUX Port
    csiDSR = ord(b"n")  # Device Status Report
    csiKEY_CODE = ord(b"~")  # VT Sequences
    cisSCP = ord(b"s")  #  Save Current Cursor Position
    csiRCP = ord(b"u")  #  Restore Saved Cursor Position

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


cdef class Stream:
    """TTY Stream handler that processes whatever it's fed."""

    def __init__(self, screen: Screen):
        self._screen = screen

    @property
    def screen(self) -> Screen:
        return self._screen

    def feed(self, data: bytes):
        """Process input to the terminal."""
        cdef unsigned char byte
        cdef unsigned char *glyph
        biter = ByteIterator(data)
        utf8 = bytes(4)
        glyph = <unsigned char*>utf8

        while not biter.empty:
            byte = biter.next()

            if self.is_control(byte):
                self._control_characters(byte, biter)
            if self.is_utf8(byte):
                if self._utf8_characters(byte, biter, glyph):
                    self._output_printable(utf8)
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

    cdef inline bint _control_characters(self, unsigned char byte, ByteIterator iterator):
        """Process a control character."""
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
            self._escape_sequence(iterator)
        else:
            return False

    cdef inline bint _escape_sequence(self, ByteIterator iterator):
        """Process an escape sequence."""
        cdef unsigned char byte = 0

        if not iterator.empty:
            byte = iterator.next()

        if byte == escSS2:
            pass
        elif byte == escSS3:
            pass
        elif byte == escDCS:
            pass
        elif byte == escSCI:
            pass
        elif byte == escST:
            pass
        elif byte == escOSC:
            pass
        elif byte == escPM:
            pass
        elif byte == escAPC:
            pass
        else:
            return False

    cdef inline bint _output_printable(self, bytes glyph):
        """Output glyph to screen."""
        pass

cdef class Terminal:
    pass
