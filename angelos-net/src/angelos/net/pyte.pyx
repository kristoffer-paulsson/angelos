# cython: language_level=3
#
# Cython port and adaption of https://github.com/selectel/pyte by Kristoffer Paulsson (March 2021)
#
# Copyright
# =========
#
# (c) 2011-2012 by Selectel.
# (c) 2012-2017 by pyte authors and contributors.
# (c) 2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# Authors
# =======
#
# - George Shuklin
# - Sergei Lebedev
#
# Contributors
# ------------
#
# - Alexey Shamrin
# - Steve Cohen
# - Jonathan Slenders
# - David O'Shea
# - Andreas Stührk
# - Dmitriy Novozhilov
# - Sergey Zavgorodniy
# - Byron Roosa
# - Andrew Crozier
# - @eight04
#
#
#                   GNU LESSER GENERAL PUBLIC LICENSE
#                       Version 3, 29 June 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.
#
#
#   This version of the GNU Lesser General Public License incorporates
# the terms and conditions of version 3 of the GNU General Public
# License, supplemented by the additional permissions listed below.
#
#  0. Additional Definitions.
#
#   As used herein, "this License" refers to version 3 of the GNU Lesser
# General Public License, and the "GNU GPL" refers to version 3 of the GNU
# General Public License.
#
#   "The Library" refers to a covered work governed by this License,
# other than an Application or a Combined Work as defined below.
#
#   An "Application" is any work that makes use of an interface provided
# by the Library, but which is not otherwise based on the Library.
# Defining a subclass of a class defined by the Library is deemed a mode
# of using an interface provided by the Library.
#
#   A "Combined Work" is a work produced by combining or linking an
# Application with the Library.  The particular version of the Library
# with which the Combined Work was made is also called the "Linked
# Version".
#
#   The "Minimal Corresponding Source" for a Combined Work means the
# Corresponding Source for the Combined Work, excluding any source code
# for portions of the Combined Work that, considered in isolation, are
# based on the Application, and not on the Linked Version.
#
#   The "Corresponding Application Code" for a Combined Work means the
# object code and/or source code for the Application, including any data
# and utility programs needed for reproducing the Combined Work from the
# Application, but excluding the System Libraries of the Combined Work.
#
#   1. Exception to Section 3 of the GNU GPL.

#   You may convey a covered work under sections 3 and 4 of this License
# without being bound by section 3 of the GNU GPL.
#
#   2. Conveying Modified Versions.
#
#   If you modify a copy of the Library, and, in your modifications, a
# facility refers to a function or data to be supplied by an Application
# that uses the facility (other than as an argument passed when the
# facility is invoked), then you may convey a copy of the modified
# version:
#
#    a) under this License, provided that you make a good faith effort to
#    ensure that, in the event an Application does not supply the
#    function or data, the facility still operates, and performs
#    whatever part of its purpose remains meaningful, or
#
#    b) under the GNU GPL, with none of the additional permissions of
#    this License applicable to that copy.
#
#   3. Object Code Incorporating Material from Library Header Files.
#
#   The object code form of an Application may incorporate material from
# a header file that is part of the Library.  You may convey such object
# code under terms of your choice, provided that, if the incorporated
# material is not limited to numerical parameters, data structure
# layouts and accessors, or small macros, inline functions and templates
# (ten or fewer lines in length), you do both of the following:
#
#    a) Give prominent notice with each copy of the object code that the
#    Library is used in it and that the Library and its use are
#    covered by this License.
#
#    b) Accompany the object code with a copy of the GNU GPL and this license
#    document.
#
#   4. Combined Works.
#
#   You may convey a Combined Work under terms of your choice that,
# taken together, effectively do not restrict modification of the
# portions of the Library contained in the Combined Work and reverse
# engineering for debugging such modifications, if you also do each of
# the following:
#
#    a) Give prominent notice with each copy of the Combined Work that
#    the Library is used in it and that the Library and its use are
#    covered by this License.
#
#    b) Accompany the Combined Work with a copy of the GNU GPL and this license
#    document.
#
#    c) For a Combined Work that displays copyright notices during
#    execution, include the copyright notice for the Library among
#    these notices, as well as a reference directing the user to the
#    copies of the GNU GPL and this license document.
#
#    d) Do one of the following:
#
#        0) Convey the Minimal Corresponding Source under the terms of this
#        License, and the Corresponding Application Code in a form
#        suitable for, and under terms that permit, the user to
#        recombine or relink the Application with a modified version of
#        the Linked Version to produce a modified Combined Work, in the
#        manner specified by section 6 of the GNU GPL for conveying
#        Corresponding Source.
#
#        1) Use a suitable shared library mechanism for linking with the
#        Library.  A suitable mechanism is one that (a) uses at run time
#        a copy of the Library already present on the user's computer
#        system, and (b) will operate properly with a modified version
#        of the Library that is interface-compatible with the Linked
#        Version.
#
#    e) Provide Installation Information, but only if you would otherwise
#    be required to provide such information under section 6 of the
#    GNU GPL, and only to the extent that such information is
#    necessary to install and execute a modified version of the
#    Combined Work produced by recombining or relinking the
#    Application with a modified version of the Linked Version. (If
#    you use option 4d0, the Installation Information must accompany
#    the Minimal Corresponding Source and Corresponding Application
#    Code. If you use option 4d1, you must provide the Installation
#    Information in the manner specified by section 6 of the GNU GPL
#    for conveying Corresponding Source.)
#
#   5. Combined Libraries.
#
#   You may place library facilities that are a work based on the
# Library side by side in a single library together with other library
# facilities that are not Applications and are not covered by this
# License, and convey such a combined library under terms of your
# choice, if you do both of the following:
#
#    a) Accompany the combined library with a copy of the same work based
#    on the Library, uncombined with any other library facilities,
#    conveyed under the terms of this License.
#
#    b) Give prominent notice with the combined library that part of it
#    is a work based on the Library, and explaining where to find the
#    accompanying uncombined form of the same work.
#
#   6. Revised Versions of the GNU Lesser General Public License.
#
#   The Free Software Foundation may publish revised and/or new versions
# of the GNU Lesser General Public License from time to time. Such new
# versions will be similar in spirit to the present version, but may
# differ in detail to address new problems or concerns.
#
#   Each version is given a distinguishing version number. If the
# Library as you received it specifies that a certain numbered version
# of the GNU Lesser General Public License "or any later version"
# applies to it, you have the option of following the terms and
# conditions either of that published version or of any later version
# published by the Free Software Foundation. If the Library as you
# received it does not specify a version number of the GNU Lesser
# General Public License, you may choose any version of the GNU Lesser
# General Public License ever published by the Free Software Foundation.
#
#   If the Library as you received it specifies that a proxy can decide
# whether future versions of the GNU Lesser General Public License shall
# apply, that proxy's public statement of acceptance of any version is
# permanent authorization for you to choose that version for the
# Library.
#
"""Virtual terminal stuff."""

import codecs
import copy
import itertools
import json
import math
import os
import re
import sys
import unicodedata
import warnings
from collections import namedtuple, deque, defaultdict
from struct import Struct

from angelos.ctl.wcwidth import wcwidth

#: A mapping of ANSI text style codes to style names, "+" means the:
#: attribute is set, "-" -- reset; example:
#:
#: >>> text[1]
#: '+bold'
#: >>> text[9]
#: '+strikethrough'
TEXT = {
    1: "+bold",
    3: "+italics",
    4: "+underscore",
    5: "+blink",
    7: "+reverse",
    9: "+strikethrough",
    22: "-bold",
    23: "-italics",
    24: "-underscore",
    25: "-blink",
    27: "-reverse",
    29: "-strikethrough",
}

#: A mapping of ANSI foreground color codes to color names.
#:
#: >>> FG_ANSI[30]
#: 'black'
#: >>> FG_ANSI[38]
#: 'default'
FG_ANSI = {
    30: "black",
    31: "red",
    32: "green",
    33: "brown",
    34: "blue",
    35: "magenta",
    36: "cyan",
    37: "white",
    39: "default"  # white.
}

#: An alias to :data:`~pyte.graphics.FG_ANSI` for compatibility.
FG = FG_ANSI

#: A mapping of non-standard ``aixterm`` foreground color codes to
#: color names. These are high intensity colors.
FG_AIXTERM = {
    90: "brightblack",
    91: "brightred",
    92: "brightgreen",
    93: "brightbrown",
    94: "brightblue",
    95: "brightmagenta",
    96: "brightcyan",
    97: "brightwhite"
}

#: A mapping of ANSI background color codes to color names.
#:
#: >>> BG_ANSI[40]
#: 'black'
#: >>> BG_ANSI[48]
#: 'default'
BG_ANSI = {
    40: "black",
    41: "red",
    42: "green",
    43: "brown",
    44: "blue",
    45: "magenta",
    46: "cyan",
    47: "white",
    49: "default"  # black.
}

#: An alias to :data:`~pyte.graphics.BG_ANSI` for compatibility.
BG = BG_ANSI

#: A mapping of non-standard ``aixterm`` background color codes to
#: color names. These are high intensity colors.
BG_AIXTERM = {
    100: "brightblack",
    101: "brightred",
    102: "brightgreen",
    103: "brightbrown",
    104: "brightblue",
    105: "bfightmagenta",
    106: "brightcyan",
    107: "brightwhite"
}

#: SGR code for foreground in 256 or True color mode.
FG_256 = 38

#: SGR code for background in 256 or True color mode.
BG_256 = 48

#: A table of 256 foreground or background colors.
# The following code is part of the Pygments project (BSD licensed).
FG_BG_256 = [
    (0x00, 0x00, 0x00),  # 0
    (0xcd, 0x00, 0x00),  # 1
    (0x00, 0xcd, 0x00),  # 2
    (0xcd, 0xcd, 0x00),  # 3
    (0x00, 0x00, 0xee),  # 4
    (0xcd, 0x00, 0xcd),  # 5
    (0x00, 0xcd, 0xcd),  # 6
    (0xe5, 0xe5, 0xe5),  # 7
    (0x7f, 0x7f, 0x7f),  # 8
    (0xff, 0x00, 0x00),  # 9
    (0x00, 0xff, 0x00),  # 10
    (0xff, 0xff, 0x00),  # 11
    (0x5c, 0x5c, 0xff),  # 12
    (0xff, 0x00, 0xff),  # 13
    (0x00, 0xff, 0xff),  # 14
    (0xff, 0xff, 0xff),  # 15
]

# colors 16..231: the 6x6x6 color cube
valuerange = (0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff)

for i in range(216):
    r = valuerange[(i // 36) % 6]
    g = valuerange[(i // 6) % 6]
    b = valuerange[i % 6]
    FG_BG_256.append((r, g, b))

# colors 232..255: grayscale
for i in range(24):
    v = 8 + i * 10
    FG_BG_256.append((v, v, v))

FG_BG_256 = ["{0:02x}{1:02x}{2:02x}".format(r, g, b) for r, g, b in FG_BG_256]

class CtrlCodes:
    #: *Space*: Not suprisingly -- ``" "``.
    SP = " "

    #: *Null*: Does nothing.
    NUL = "\x00"

    #: *Bell*: Beeps.
    BEL = "\x07"

    #: *Backspace*: Backspace one column, but not past the begining of the
    #: line.
    BS = "\x08"

    #: *Horizontal tab*: Move cursor to the next tab stop, or to the end
    #: of the line if there is no earlier tab stop.
    HT = "\x09"

    #: *Linefeed*: Give a line feed, and, if :data:`pyte.modes.LNM` (new
    #: line mode) is set also a carriage return.
    LF = "\n"
    #: *Vertical tab*: Same as :data:`LF`.
    VT = "\x0b"
    #: *Form feed*: Same as :data:`LF`.
    FF = "\x0c"

    #: *Carriage return*: Move cursor to left margin on current line.
    CR = "\r"

    #: *Shift out*: Activate G1 character set.
    SO = "\x0e"

    #: *Shift in*: Activate G0 character set.
    SI = "\x0f"

    #: *Cancel*: Interrupt escape sequence. If received during an escape or
    #: control sequence, cancels the sequence and displays substitution
    #: character.
    CAN = "\x18"
    #: *Substitute*: Same as :data:`CAN`.
    SUB = "\x1a"

    #: *Escape*: Starts an escape sequence.
    ESC = "\x1b"

    #: *Delete*: Is ignored.
    DEL = "\x7f"

    #: *Control sequence introducer*.
    CSI_C0 = ESC + "["
    CSI_C1 = "\x9b"
    CSI = CSI_C0

    #: *String terminator*.
    ST_C0 = ESC + "\\"
    ST_C1 = "\x9c"
    ST = ST_C0

    #: *Operating system command*.
    OSC_C0 = ESC + "]"
    OSC_C1 = "\x9d"
    OSC = OSC_C0


class EscCodes:
    #: *Reset*.
    RIS = "c"

    #: *Index*: Move cursor down one line in same column. If the cursor is
    #: at the bottom margin, the screen performs a scroll-up.
    IND = "D"

    #: *Next line*: Same as :data:`pyte.control.LF`.
    NEL = "E"

    #: Tabulation set: Set a horizontal tab stop at cursor position.
    HTS = "H"

    #: *Reverse index*: Move cursor up one line in same column. If the
    #: cursor is at the top margin, the screen performs a scroll-down.
    RI = "M"

    #: Save cursor: Save cursor position, character attribute (graphic
    #: rendition), character set, and origin mode selection (see
    #: :data:`DECRC`).
    DECSC = "7"

    #: *Restore cursor*: Restore previously saved cursor position, character
    #: attribute (graphic rendition), character set, and origin mode
    #: selection. If none were saved, move cursor to home position.
    DECRC = "8"

    # "Sharp" escape sequences.
    # -------------------------

    #: *Alignment display*: Fill screen with uppercase E's for testing
    #: screen focus and alignment.
    DECALN = "8"


    # ECMA-48 CSI sequences.
    # ---------------------

    #: *Insert character*: Insert the indicated # of blank characters.
    ICH = "@"

    #: *Cursor up*: Move cursor up the indicated # of lines in same column.
    #: Cursor stops at top margin.
    CUU = "A"

    #: *Cursor down*: Move cursor down the indicated # of lines in same
    #: column. Cursor stops at bottom margin.
    CUD = "B"

    #: *Cursor forward*: Move cursor right the indicated # of columns.
    #: Cursor stops at right margin.
    CUF = "C"

    #: *Cursor back*: Move cursor left the indicated # of columns. Cursor
    #: stops at left margin.
    CUB = "D"

    #: *Cursor next line*: Move cursor down the indicated # of lines to
    #: column 1.
    CNL = "E"

    #: *Cursor previous line*: Move cursor up the indicated # of lines to
    #: column 1.
    CPL = "F"

    #: *Cursor horizontal align*: Move cursor to the indicated column in
    #: current line.
    CHA = "G"

    #: *Cursor position*: Move cursor to the indicated line, column (origin
    #: at ``1, 1``).
    CUP = "H"

    #: *Erase data* (default: from cursor to end of line).
    ED = "J"

    #: *Erase in line* (default: from cursor to end of line).
    EL = "K"

    #: *Insert line*: Insert the indicated # of blank lines, starting from
    #: the current line. Lines displayed below cursor move down. Lines moved
    #: past the bottom margin are lost.
    IL = "L"

    #: *Delete line*: Delete the indicated # of lines, starting from the
    #: current line. As lines are deleted, lines displayed below cursor
    #: move up. Lines added to bottom of screen have spaces with same
    #: character attributes as last line move up.
    DL = "M"

    #: *Delete character*: Delete the indicated # of characters on the
    #: current line. When character is deleted, all characters to the right
    #: of cursor move left.
    DCH = "P"

    #: *Erase character*: Erase the indicated # of characters on the
    #: current line.
    ECH = "X"

    #: *Horizontal position relative*: Same as :data:`CUF`.
    HPR = "a"

    #: *Device Attributes*.
    DA = "c"

    #: *Vertical position adjust*: Move cursor to the indicated line,
    #: current column.
    VPA = "d"

    #: *Vertical position relative*: Same as :data:`CUD`.
    VPR = "e"

    #: *Horizontal / Vertical position*: Same as :data:`CUP`.
    HVP = "f"

    #: *Tabulation clear*: Clears a horizontal tab stop at cursor position.
    TBC = "g"

    #: *Set mode*.
    SM = "h"

    #: *Reset mode*.
    RM = "l"

    #: *Select graphics rendition*: The terminal can display the following
    #: character attributes that change the character display without
    #: changing the character (see :mod:`pyte.graphics`).
    SGR = "m"

    #: *Device status report*.
    DSR = "n"

    #: *Select top and bottom margins*: Selects margins, defining the
    #: scrolling region; parameters are top and bottom line. If called
    #: without any arguments, whole screen is used.
    DECSTBM = "r"

    #: *Horizontal position adjust*: Same as :data:`CHA`.
    HPA = "'"


def pass_through_str(data):
    """Decode :func:`bytes` to :func:`str` using pass-through encoding."""
    return "".join(map(chr, data))


#: *Line Feed/New Line Mode*: When enabled, causes a received
#: :data:`~pyte.control.LF`, :data:`pyte.control.FF`, or
#: :data:`~pyte.control.VT` to move the cursor to the first column of
#: the next line.
LNM = 20

#: *Insert/Replace Mode*: When enabled, new display characters move
#: old display characters to the right. Characters moved past the
#: right margin are lost. Otherwise, new display characters replace
#: old display characters at the cursor position.
IRM = 4


# Private modes.
# ..............

#: *Text Cursor Enable Mode*: determines if the text cursor is
#: visible.
DECTCEM = 25 << 5

#: *Screen Mode*: toggles screen-wide reverse-video mode.
DECSCNM = 5 << 5

#: *Origin Mode*: allows cursor addressing relative to a user-defined
#: origin. This mode resets when the terminal is powered up or reset.
#: It does not affect the erase in display (ED) function.
DECOM = 6 << 5

#: *Auto Wrap Mode*: selects where received graphic characters appear
#: when the cursor is at the right margin.
DECAWM = 7 << 5

#: *Column Mode*: selects the number of columns per line (80 or 132)
#: on the screen.
DECCOLM = 3 << 5


#: Latin1.
LAT1_MAP = "".join(map(chr, range(256)))

#: VT100 graphic character set.
VT100_MAP = "".join(chr(c) for c in [
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
    0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
    0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
    0x0028, 0x0029, 0x002a, 0x2192, 0x2190, 0x2191, 0x2193, 0x002f,
    0x2588, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
    0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
    0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
    0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x00a0,
    0x25c6, 0x2592, 0x2409, 0x240c, 0x240d, 0x240a, 0x00b0, 0x00b1,
    0x2591, 0x240b, 0x2518, 0x2510, 0x250c, 0x2514, 0x253c, 0x23ba,
    0x23bb, 0x2500, 0x23bc, 0x23bd, 0x251c, 0x2524, 0x2534, 0x252c,
    0x2502, 0x2264, 0x2265, 0x03c0, 0x2260, 0x00a3, 0x00b7, 0x007f,
    0x0080, 0x0081, 0x0082, 0x0083, 0x0084, 0x0085, 0x0086, 0x0087,
    0x0088, 0x0089, 0x008a, 0x008b, 0x008c, 0x008d, 0x008e, 0x008f,
    0x0090, 0x0091, 0x0092, 0x0093, 0x0094, 0x0095, 0x0096, 0x0097,
    0x0098, 0x0099, 0x009a, 0x009b, 0x009c, 0x009d, 0x009e, 0x009f,
    0x00a0, 0x00a1, 0x00a2, 0x00a3, 0x00a4, 0x00a5, 0x00a6, 0x00a7,
    0x00a8, 0x00a9, 0x00aa, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x00af,
    0x00b0, 0x00b1, 0x00b2, 0x00b3, 0x00b4, 0x00b5, 0x00b6, 0x00b7,
    0x00b8, 0x00b9, 0x00ba, 0x00bb, 0x00bc, 0x00bd, 0x00be, 0x00bf,
    0x00c0, 0x00c1, 0x00c2, 0x00c3, 0x00c4, 0x00c5, 0x00c6, 0x00c7,
    0x00c8, 0x00c9, 0x00ca, 0x00cb, 0x00cc, 0x00cd, 0x00ce, 0x00cf,
    0x00d0, 0x00d1, 0x00d2, 0x00d3, 0x00d4, 0x00d5, 0x00d6, 0x00d7,
    0x00d8, 0x00d9, 0x00da, 0x00db, 0x00dc, 0x00dd, 0x00de, 0x00df,
    0x00e0, 0x00e1, 0x00e2, 0x00e3, 0x00e4, 0x00e5, 0x00e6, 0x00e7,
    0x00e8, 0x00e9, 0x00ea, 0x00eb, 0x00ec, 0x00ed, 0x00ee, 0x00ef,
    0x00f0, 0x00f1, 0x00f2, 0x00f3, 0x00f4, 0x00f5, 0x00f6, 0x00f7,
    0x00f8, 0x00f9, 0x00fa, 0x00fb, 0x00fc, 0x00fd, 0x00fe, 0x00ff
])

#: IBM Codepage 437.
IBMPC_MAP = "".join(chr(c) for c in [
    0x0000, 0x263a, 0x263b, 0x2665, 0x2666, 0x2663, 0x2660, 0x2022,
    0x25d8, 0x25cb, 0x25d9, 0x2642, 0x2640, 0x266a, 0x266b, 0x263c,
    0x25b6, 0x25c0, 0x2195, 0x203c, 0x00b6, 0x00a7, 0x25ac, 0x21a8,
    0x2191, 0x2193, 0x2192, 0x2190, 0x221f, 0x2194, 0x25b2, 0x25bc,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
    0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
    0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
    0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
    0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
    0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
    0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x2302,
    0x00c7, 0x00fc, 0x00e9, 0x00e2, 0x00e4, 0x00e0, 0x00e5, 0x00e7,
    0x00ea, 0x00eb, 0x00e8, 0x00ef, 0x00ee, 0x00ec, 0x00c4, 0x00c5,
    0x00c9, 0x00e6, 0x00c6, 0x00f4, 0x00f6, 0x00f2, 0x00fb, 0x00f9,
    0x00ff, 0x00d6, 0x00dc, 0x00a2, 0x00a3, 0x00a5, 0x20a7, 0x0192,
    0x00e1, 0x00ed, 0x00f3, 0x00fa, 0x00f1, 0x00d1, 0x00aa, 0x00ba,
    0x00bf, 0x2310, 0x00ac, 0x00bd, 0x00bc, 0x00a1, 0x00ab, 0x00bb,
    0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x2561, 0x2562, 0x2556,
    0x2555, 0x2563, 0x2551, 0x2557, 0x255d, 0x255c, 0x255b, 0x2510,
    0x2514, 0x2534, 0x252c, 0x251c, 0x2500, 0x253c, 0x255e, 0x255f,
    0x255a, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256c, 0x2567,
    0x2568, 0x2564, 0x2565, 0x2559, 0x2558, 0x2552, 0x2553, 0x256b,
    0x256a, 0x2518, 0x250c, 0x2588, 0x2584, 0x258c, 0x2590, 0x2580,
    0x03b1, 0x00df, 0x0393, 0x03c0, 0x03a3, 0x03c3, 0x00b5, 0x03c4,
    0x03a6, 0x0398, 0x03a9, 0x03b4, 0x221e, 0x03c6, 0x03b5, 0x2229,
    0x2261, 0x00b1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00f7, 0x2248,
    0x00b0, 0x2219, 0x00b7, 0x221a, 0x207f, 0x00b2, 0x25a0, 0x00a0
])


#: VAX42 character set.
VAX42_MAP = "".join(chr(c) for c in [
    0x0000, 0x263a, 0x263b, 0x2665, 0x2666, 0x2663, 0x2660, 0x2022,
    0x25d8, 0x25cb, 0x25d9, 0x2642, 0x2640, 0x266a, 0x266b, 0x263c,
    0x25b6, 0x25c0, 0x2195, 0x203c, 0x00b6, 0x00a7, 0x25ac, 0x21a8,
    0x2191, 0x2193, 0x2192, 0x2190, 0x221f, 0x2194, 0x25b2, 0x25bc,
    0x0020, 0x043b, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
    0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
    0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x0435,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
    0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
    0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0441, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
    0x0435, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x043a,
    0x0070, 0x0071, 0x0442, 0x0073, 0x043b, 0x0435, 0x0076, 0x0077,
    0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x2302,
    0x00c7, 0x00fc, 0x00e9, 0x00e2, 0x00e4, 0x00e0, 0x00e5, 0x00e7,
    0x00ea, 0x00eb, 0x00e8, 0x00ef, 0x00ee, 0x00ec, 0x00c4, 0x00c5,
    0x00c9, 0x00e6, 0x00c6, 0x00f4, 0x00f6, 0x00f2, 0x00fb, 0x00f9,
    0x00ff, 0x00d6, 0x00dc, 0x00a2, 0x00a3, 0x00a5, 0x20a7, 0x0192,
    0x00e1, 0x00ed, 0x00f3, 0x00fa, 0x00f1, 0x00d1, 0x00aa, 0x00ba,
    0x00bf, 0x2310, 0x00ac, 0x00bd, 0x00bc, 0x00a1, 0x00ab, 0x00bb,
    0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x2561, 0x2562, 0x2556,
    0x2555, 0x2563, 0x2551, 0x2557, 0x255d, 0x255c, 0x255b, 0x2510,
    0x2514, 0x2534, 0x252c, 0x251c, 0x2500, 0x253c, 0x255e, 0x255f,
    0x255a, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256c, 0x2567,
    0x2568, 0x2564, 0x2565, 0x2559, 0x2558, 0x2552, 0x2553, 0x256b,
    0x256a, 0x2518, 0x250c, 0x2588, 0x2584, 0x258c, 0x2590, 0x2580,
    0x03b1, 0x00df, 0x0393, 0x03c0, 0x03a3, 0x03c3, 0x00b5, 0x03c4,
    0x03a6, 0x0398, 0x03a9, 0x03b4, 0x221e, 0x03c6, 0x03b5, 0x2229,
    0x2261, 0x00b1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00f7, 0x2248,
    0x00b0, 0x2219, 0x00b7, 0x221a, 0x207f, 0x00b2, 0x25a0, 0x00a0
])


MAPS = {
    "B": LAT1_MAP,
    "0": VT100_MAP,
    "U": IBMPC_MAP,
    "V": VAX42_MAP
}


class Stream(object):
    """A stream is a state machine that parses a stream of bytes and
    dispatches events based on what it sees.
    :param pyte.screens.Screen screen: a screen to dispatch events to.
    :param bool strict: check if a given screen implements all required
                        events.
    .. note::
       Stream only accepts text as input, but if for some reason
       you need to feed it with bytes, consider using
       :class:`~pyte.streams.ByteStream` instead.
    .. versionchanged 0.6.0::
       For performance reasons the binding between stream events and
       screen methods was made static. As a result, the stream **will
       not** dispatch events to methods added to screen **after** the
       stream was created.
    .. seealso::
        `man console_codes <http://linux.die.net/man/4/console_codes>`_
            For details on console codes listed bellow in :attr:`basic`,
            :attr:`escape`, :attr:`csi`, :attr:`sharp`.
    """

    #: Control sequences, which don't require any arguments.
    basic = {
        CtrlCodes.BEL: "bell",
        CtrlCodes.BS: "backspace",
        CtrlCodes.HT: "tab",
        CtrlCodes.LF: "linefeed",
        CtrlCodes.VT: "linefeed",
        CtrlCodes.FF: "linefeed",
        CtrlCodes.CR: "carriage_return",
        CtrlCodes.SO: "shift_out",
        CtrlCodes.SI: "shift_in",
    }

    #: non-CSI escape sequences.
    escape = {
        EscCodes.RIS: "reset",
        EscCodes.IND: "index",
        EscCodes.NEL: "linefeed",
        EscCodes.RI: "reverse_index",
        EscCodes.HTS: "set_tab_stop",
        EscCodes.DECSC: "save_cursor",
        EscCodes.DECRC: "restore_cursor",
    }

    #: "sharp" escape sequences -- ``ESC # <N>``.
    sharp = {
        EscCodes.DECALN: "alignment_display",
    }

    #: CSI escape sequences -- ``CSI P1;P2;...;Pn <fn>``.
    csi = {
        EscCodes.ICH: "insert_characters",
        EscCodes.CUU: "cursor_up",
        EscCodes.CUD: "cursor_down",
        EscCodes.CUF: "cursor_forward",
        EscCodes.CUB: "cursor_back",
        EscCodes.CNL: "cursor_down1",
        EscCodes.CPL: "cursor_up1",
        EscCodes.CHA: "cursor_to_column",
        EscCodes.CUP: "cursor_position",
        EscCodes.ED: "erase_in_display",
        EscCodes.EL: "erase_in_line",
        EscCodes.IL: "insert_lines",
        EscCodes.DL: "delete_lines",
        EscCodes.DCH: "delete_characters",
        EscCodes.ECH: "erase_characters",
        EscCodes.HPR: "cursor_forward",
        EscCodes.DA: "report_device_attributes",
        EscCodes.VPA: "cursor_to_line",
        EscCodes.VPR: "cursor_down",
        EscCodes.HVP: "cursor_position",
        EscCodes.TBC: "clear_tab_stop",
        EscCodes.SM: "set_mode",
        EscCodes.RM: "reset_mode",
        EscCodes.SGR: "select_graphic_rendition",
        EscCodes.DSR: "report_device_status",
        EscCodes.DECSTBM: "set_margins",
        EscCodes.HPA: "cursor_to_column"
    }

    #: A set of all events dispatched by the stream.
    events = frozenset(itertools.chain(
        basic.values(), escape.values(), sharp.values(), csi.values(),
        ["define_charset"],
        ["set_icon_name", "set_title"],  # OSC.
        ["draw", "debug"]))

    #: A regular expression pattern matching everything what can be
    #: considered plain text.
    _special = set([CtrlCodes.ESC, CtrlCodes.CSI_C1, CtrlCodes.NUL, CtrlCodes.DEL, CtrlCodes.OSC_C1])
    _special.update(basic)
    _text_pattern = re.compile(
        "[^" + "".join(map(re.escape, _special)) + "]+")
    del _special

    def __init__(self, screen=None, strict=True):
        self.listener = None
        self.strict = strict
        self.use_utf8 = True

        if screen is not None:
            self.attach(screen)

    def attach(self, screen):
        """Adds a given screen to the listener queue.
        :param pyte.screens.Screen screen: a screen to attach to.
        """
        if self.listener is not None:
            warnings.warn("As of version 0.6.0 the listener queue is "
                          "restricted to a single element. Existing "
                          "listener {0} will be replaced."
                          .format(self.listener), DeprecationWarning)

        if self.strict:
            for event in self.events:
                if not hasattr(screen, event):
                    raise TypeError("{0} is missing {1}".format(screen, event))

        self.listener = screen
        self._parser = None
        self._initialize_parser()

    def detach(self, screen):
        """Remove a given screen from the listener queue and fails
        silently if it's not attached.
        :param pyte.screens.Screen screen: a screen to detach.
        """
        if screen is self.listener:
            self.listener = None

    def feed(self, data):
        """Consume some data and advances the state as necessary.
        :param str data: a blob of data to feed from.
        """
        send = self._send_to_parser
        draw = self.listener.draw
        match_text = self._text_pattern.match
        taking_plain_text = self._taking_plain_text

        length = len(data)
        offset = 0
        while offset < length:
            if taking_plain_text:
                match = match_text(data, offset)
                if match:
                    start, offset = match.span()
                    draw(data[start:offset])
                else:
                    taking_plain_text = False
            else:
                taking_plain_text = send(data[offset:offset + 1])
                offset += 1

        self._taking_plain_text = taking_plain_text

    def _send_to_parser(self, data):
        try:
            return self._parser.send(data)
        except Exception:
            # Reset the parser state to make sure it is usable even
            # after receiving an exception. See PR #101 for details.
            self._initialize_parser()
            raise

    def _initialize_parser(self):
        self._parser = self._parser_fsm()
        self._taking_plain_text = next(self._parser)

    def _parser_fsm(self):
        """An FSM implemented as a coroutine.
        This generator is not the most beautiful, but it is as performant
        as possible. When a process generates a lot of output, then this
        will be the bottleneck, because it processes just one character
        at a time.
        Don't change anything without profiling first.
        """
        basic = self.basic
        listener = self.listener
        draw = listener.draw
        debug = listener.debug

        ESC, CSI_C1 = CtrlCodes.ESC, CtrlCodes.CSI_C1
        OSC_C1 = CtrlCodes.OSC_C1
        SP_OR_GT = CtrlCodes.SP + ">"
        NUL_OR_DEL = CtrlCodes.NUL + CtrlCodes.DEL
        CAN_OR_SUB = CtrlCodes.CAN + CtrlCodes.SUB
        ALLOWED_IN_CSI = "".join([CtrlCodes.BEL, CtrlCodes.BS, CtrlCodes.HT, CtrlCodes.LF, CtrlCodes.VT, CtrlCodes.FF, CtrlCodes.CR])
        OSC_TERMINATORS = set([CtrlCodes.ST_C0, CtrlCodes.ST_C1, CtrlCodes.BEL])

        def create_dispatcher(mapping):
            return defaultdict(lambda: debug, dict(
                (event, getattr(listener, attr))
                for event, attr in mapping.items()))

        basic_dispatch = create_dispatcher(basic)
        sharp_dispatch = create_dispatcher(self.sharp)
        escape_dispatch = create_dispatcher(self.escape)
        csi_dispatch = create_dispatcher(self.csi)

        while True:
            # ``True`` tells ``Screen.feed`` that it is allowed to send
            # chunks of plain text directly to the listener, instead
            # of this generator.
            char = yield True

            if char == ESC:
                # Most non-VT52 commands start with a left-bracket after the
                # escape and then a stream of parameters and a command; with
                # a single notable exception -- :data:`escape.DECOM` sequence,
                # which starts with a sharp.
                #
                # .. versionchanged:: 0.4.10
                #
                #    For compatibility with Linux terminal stream also
                #    recognizes ``ESC % C`` sequences for selecting control
                #    character set. However, in the current version these
                #    are noop.
                char = yield
                if char == "[":
                    char = CSI_C1  # Go to CSI.
                elif char == "]":
                    char = OSC_C1  # Go to OSC.
                else:
                    if char == "#":
                        sharp_dispatch[(yield)]()
                    elif char == "%":
                        self.select_other_charset((yield))
                    elif char in "()":
                        code = yield
                        if self.use_utf8:
                            continue

                        # See http://www.cl.cam.ac.uk/~mgk25/unicode.html#term
                        # for the why on the UTF-8 restriction.
                        listener.define_charset(code, mode=char)
                    else:
                        escape_dispatch[char]()
                    continue    # Don't go to CSI.

            if char in basic:
                # Ignore shifts in UTF-8 mode. See
                # http://www.cl.cam.ac.uk/~mgk25/unicode.html#term for
                # the why on UTF-8 restriction.
                if (char == CtrlCodes.SI or char == CtrlCodes.SO) and self.use_utf8:
                    continue

                basic_dispatch[char]()
            elif char == CSI_C1:
                # All parameters are unsigned, positive decimal integers, with
                # the most significant digit sent first. Any parameter greater
                # than 9999 is set to 9999. If you do not specify a value, a 0
                # value is assumed.
                #
                # .. seealso::
                #
                #    `VT102 User Guide <http://vt100.net/docs/vt102-ug/>`_
                #        For details on the formatting of escape arguments.
                #
                #    `VT220 Programmer Ref. <http://vt100.net/docs/vt220-rm/>`_
                #        For details on the characters valid for use as
                #        arguments.
                params = []
                current = ""
                private = False
                while True:
                    char = yield
                    if char == "?":
                        private = True
                    elif char in ALLOWED_IN_CSI:
                        basic_dispatch[char]()
                    elif char in SP_OR_GT:
                        pass  # Secondary DA is not supported atm.
                    elif char in CAN_OR_SUB:
                        # If CAN or SUB is received during a sequence, the
                        # current sequence is aborted; terminal displays
                        # the substitute character, followed by characters
                        # in the sequence received after CAN or SUB.
                        draw(char)
                        break
                    elif char.isdigit():
                        current += char
                    elif char == "$":
                        # XTerm-specific ESC]...$[a-z] sequences are not
                        # currently supported.
                        yield
                        break
                    else:
                        params.append(min(int(current or 0), 9999))

                        if char == ";":
                            current = ""
                        else:
                            if private:
                                csi_dispatch[char](*params, private=True)
                            else:
                                csi_dispatch[char](*params)
                            break  # CSI is finished.
            elif char == OSC_C1:
                code = yield
                if code == "R":
                    continue  # Reset palette. Not implemented.
                elif code == "P":
                    continue  # Set palette. Not implemented.

                param = ""
                while True:
                    char = yield
                    if char == ESC:
                        char += yield
                    if char in OSC_TERMINATORS:
                        break
                    else:
                        param += char

                param = param[1:]  # Drop the ;.
                if code in "01":
                    listener.set_icon_name(param)
                if code in "02":
                    listener.set_title(param)
            elif char not in NUL_OR_DEL:
                draw(char)

    def select_other_charset(self, code):
        """Select other (non G0 or G1) charset.
        :param str code: character set code, should be a character from
                         ``"@G8"``, otherwise ignored.
        .. note:: We currently follow ``"linux"`` and only use this
                  command to switch from ISO-8859-1 to UTF-8 and back.
        .. versionadded:: 0.6.0
        .. seealso::
           `Standard ECMA-35, Section 15.4 \
           <http://ecma-international.org/publications/standards/Ecma-035.htm>`_
           for a description of VTXXX character set machinery.
        """
        # A noop since all input is Unicode-only.


class ByteStream(Stream):
    """A stream which takes bytes as input.
    Bytes are decoded to text using either UTF-8 (default) or the encoding
    selected via :meth:`~pyte.Stream.select_other_charset`.
    .. attribute:: use_utf8
       Assume the input to :meth:`~pyte.streams.ByteStream.feed` is encoded
       using UTF-8. Defaults to ``True``.
    """
    def __init__(self, *args, **kwargs):
        super(ByteStream, self).__init__(*args, **kwargs)

        self.utf8_decoder = codecs.getincrementaldecoder("utf-8")("replace")

    def feed(self, data):
        if self.use_utf8:
            data = self.utf8_decoder.decode(data)
        else:
            data = pass_through_str(data)

        super(ByteStream, self).feed(data)

    def select_other_charset(self, code):
        if code == "@":
            self.use_utf8 = False
            self.utf8_decoder.reset()
        elif code in "G8":
            self.use_utf8 = True


#: A container for screen's scroll margins.
Margins = namedtuple("Margins", "top bottom")

#: A container for savepoint, created on :data:`~pyte.escape.DECSC`.
Savepoint = namedtuple("Savepoint", [
    "cursor",
    "g0_charset",
    "g1_charset",
    "charset",
    "origin",
    "wrap"
])


class Char(namedtuple("Char", [
    "data",
    "fg",
    "bg",
    "bold",
    "italics",
    "underscore",
    "strikethrough",
    "reverse",
    "blink",
])):
    """A single styled on-screen character.
    :param str data: unicode character. Invariant: ``len(data) == 1``.
    :param str fg: foreground colour. Defaults to ``"default"``.
    :param str bg: background colour. Defaults to ``"default"``.
    :param bool bold: flag for rendering the character using bold font.
                      Defaults to ``False``.
    :param bool italics: flag for rendering the character using italic font.
                         Defaults to ``False``.
    :param bool underscore: flag for rendering the character underlined.
                            Defaults to ``False``.
    :param bool strikethrough: flag for rendering the character with a
                               strike-through line. Defaults to ``False``.
    :param bool reverse: flag for swapping foreground and background colours
                         during rendering. Defaults to ``False``.
    :param bool blink: flag for rendering the character blinked. Defaults to
                       ``False``.
    """
    __slots__ = ()

    def __new__(cls, data, fg="default", bg="default", bold=False,
                italics=False, underscore=False,
                strikethrough=False, reverse=False, blink=False):
        return super(Char, cls).__new__(cls, data, fg, bg, bold, italics,
                                        underscore, strikethrough, reverse,
                                        blink)


class CharCodes:
    """Codes describing the memory structure of a character."""

    FORMAT = Struct("!IBB??????")

    DATA = 0
    FG = 1
    BG = 2
    BOLD = 3
    ITALICS = 4
    UNDERSCORE = 5
    STRIKE = 6
    REVERSE = 7
    BLINK = 8

    @classmethod
    def default(cls) -> bytes:
        """Default character packed data."""
        return cls.FORMAT.pack(b" ", 39, 49, False, False, False, False, False, False)


class Cursor(object):
    """Screen cursor.
    :param int x: 0-based horizontal cursor position.
    :param int y: 0-based vertical cursor position.
    :param pyte.screens.Char attrs: cursor attributes (see
        :meth:`~pyte.screens.Screen.select_graphic_rendition`
        for details).
    """
    __slots__ = ("x", "y", "attrs", "hidden")

    def __init__(self, x, y, attrs=Char(" ")):
        self.x = x
        self.y = y
        self.attrs = attrs
        self.hidden = False


class StaticDefaultDict(dict):
    """A :func:`dict` with a static default value.
    Unlike :func:`collections.defaultdict` this implementation does not
    implicitly update the mapping when queried with a missing key.
    >>> d = StaticDefaultDict(42)
    >>> d["foo"]
    42
    >>> d
    {}
    """
    def __init__(self, default):
        self.default = default

    def __missing__(self, key):
        return self.default


class Screen(object):
    """
    A screen is an in-memory matrix of characters that represents the
    screen display of the terminal. It can be instantiated on its own
    and given explicit commands, or it can be attached to a stream and
    will respond to events.
    .. attribute:: buffer
       A sparse ``lines x columns`` :class:`~pyte.screens.Char` matrix.
    .. attribute:: dirty
       A set of line numbers, which should be re-drawn. The user is responsible
       for clearing this set when changes have been applied.
       >>> screen = Screen(80, 24)
       >>> screen.dirty.clear()
       >>> screen.draw("!")
       >>> list(screen.dirty)
       [0]
       .. versionadded:: 0.7.0
    .. attribute:: cursor
       Reference to the :class:`~pyte.screens.Cursor` object, holding
       cursor position and attributes.
    .. attribute:: margins
       Margins determine which screen lines move during scrolling
       (see :meth:`index` and :meth:`reverse_index`). Characters added
       outside the scrolling region do not make the screen to scroll.
       The value is ``None`` if margins are set to screen boundaries,
       otherwise -- a pair 0-based top and bottom line indices.
    .. attribute:: charset
       Current charset number; can be either ``0`` or ``1`` for `G0`
       and `G1` respectively, note that `G0` is activated by default.
    .. note::
       According to ``ECMA-48`` standard, **lines and columns are
       1-indexed**, so, for instance ``ESC [ 10;10 f`` really means
       -- move cursor to position (9, 9) in the display matrix.
    .. versionchanged:: 0.4.7
    .. warning::
       :data:`~pyte.modes.LNM` is reset by default, to match VT220
       specification. Unfortunately this makes :mod:`pyte` fail
       ``vttest`` for cursor movement.
    .. versionchanged:: 0.4.8
    .. warning::
       If `DECAWM` mode is set than a cursor will be wrapped to the
       **beginning** of the next line, which is the behaviour described
       in ``man console_codes``.
    .. seealso::
       `Standard ECMA-48, Section 6.1.1 \
       <http://ecma-international.org/publications/standards/Ecma-048.htm>`_
       for a description of the presentational component, implemented
       by ``Screen``.
    """
    @property
    def default_char(self):
        """An empty character with default foreground and background colors."""
        reverse = DECSCNM in self.mode
        return Char(data=" ", fg="default", bg="default", reverse=reverse)

    def __init__(self, columns, lines):
        self.savepoints = []
        self.columns = columns
        self.lines = lines
        self.buffer = defaultdict(lambda: StaticDefaultDict(self.default_char))
        self.dirty = set()
        self.reset()

    def __repr__(self):
        return ("{0}({1}, {2})".format(self.__class__.__name__,
                                       self.columns, self.lines))

    @property
    def display(self):
        """A :func:`list` of screen lines as unicode strings."""
        def render(line):
            is_wide_char = False
            for x in range(self.columns):
                if is_wide_char:  # Skip stub
                    is_wide_char = False
                    continue
                char = line[x].data
                assert sum(map(wcwidth, char[1:])) == 0
                is_wide_char = wcwidth(char[0]) == 2
                yield char

        return ["".join(render(self.buffer[y])) for y in range(self.lines)]

    def reset(self):
        """Reset the terminal to its initial state.
        * Scrolling margins are reset to screen boundaries.
        * Cursor is moved to home location -- ``(0, 0)`` and its
          attributes are set to defaults (see :attr:`default_char`).
        * Screen is cleared -- each character is reset to
          :attr:`default_char`.
        * Tabstops are reset to "every eight columns".
        * All lines are marked as :attr:`dirty`.
        .. note::
           Neither VT220 nor VT102 manuals mention that terminal modes
           and tabstops should be reset as well, thanks to
           :manpage:`xterm` -- we now know that.
        """
        self.dirty.update(range(self.lines))
        self.buffer.clear()
        self.margins = None

        self.mode = set([DECAWM, DECTCEM])

        self.title = ""
        self.icon_name = ""

        self.charset = 0
        self.g0_charset = LAT1_MAP
        self.g1_charset = VT100_MAP

        # From ``man terminfo`` -- "... hardware tabs are initially
        # set every `n` spaces when the terminal is powered up. Since
        # we aim to support VT102 / VT220 and linux -- we use n = 8.
        self.tabstops = set(range(8, self.columns, 8))

        self.cursor = Cursor(0, 0)
        self.cursor_position()

        self.saved_columns = None

    def resize(self, lines=None, columns=None):
        """Resize the screen to the given size.
        If the requested screen size has more lines than the existing
        screen, lines will be added at the bottom. If the requested
        size has less lines than the existing screen lines will be
        clipped at the top of the screen. Similarly, if the existing
        screen has less columns than the requested screen, columns will
        be added at the right, and if it has more -- columns will be
        clipped at the right.
        :param int lines: number of lines in the new screen.
        :param int columns: number of columns in the new screen.
        .. versionchanged:: 0.7.0
           If the requested screen size is identical to the current screen
           size, the method does nothing.
        """
        lines = lines or self.lines
        columns = columns or self.columns

        if lines == self.lines and columns == self.columns:
            return  # No changes.

        self.dirty.update(range(lines))

        if lines < self.lines:
            self.save_cursor()
            self.cursor_position(0, 0)
            self.delete_lines(self.lines - lines)  # Drop from the top.
            self.restore_cursor()

        if columns < self.columns:
            for line in self.buffer.values():
                for x in range(columns, self.columns):
                    line.pop(x, None)

        self.lines, self.columns = lines, columns
        self.set_margins()

    def set_margins(self, top=None, bottom=None):
        """Select top and bottom margins for the scrolling region.
        :param int top: the smallest line number that is scrolled.
        :param int bottom: the biggest line number that is scrolled.
        """
        # XXX 0 corresponds to the CSI with no parameters.
        if (top is None or top == 0) and bottom is None:
            self.margins = None
            return

        margins = self.margins or Margins(0, self.lines - 1)

        # Arguments are 1-based, while :attr:`margins` are zero
        # based -- so we have to decrement them by one. We also
        # make sure that both of them is bounded by [0, lines - 1].
        if top is None:
            top = margins.top
        else:
            top = max(0, min(top - 1, self.lines - 1))
        if bottom is None:
            bottom = margins.bottom
        else:
            bottom = max(0, min(bottom - 1, self.lines - 1))

        # Even though VT102 and VT220 require DECSTBM to ignore
        # regions of width less than 2, some programs (like aptitude
        # for example) rely on it. Practicality beats purity.
        if bottom - top >= 1:
            self.margins = Margins(top, bottom)

            # The cursor moves to the home position when the top and
            # bottom margins of the scrolling region (DECSTBM) changes.
            self.cursor_position()

    def set_mode(self, *modes, **kwargs):
        """Set (enable) a given list of modes.
        :param list modes: modes to set, where each mode is a constant
                           from :mod:`pyte.modes`.
        """
        # Private mode codes are shifted, to be distingiushed from non
        # private ones.
        if kwargs.get("private"):
            modes = [mode << 5 for mode in modes]
            if DECSCNM in modes:
                self.dirty.update(range(self.lines))

        self.mode.update(modes)

        # When DECOLM mode is set, the screen is erased and the cursor
        # moves to the home position.
        if DECCOLM in modes:
            self.saved_columns = self.columns
            self.resize(columns=132)
            self.erase_in_display(2)
            self.cursor_position()

        # According to VT520 manual, DECOM should also home the cursor.
        if DECOM in modes:
            self.cursor_position()

        # Mark all displayed characters as reverse.
        if DECSCNM in modes:
            for line in self.buffer.values():
                line.default = self.default_char
                for x in line:
                    line[x] = line[x]._replace(reverse=True)

            self.select_graphic_rendition(7)  # +reverse.

        # Make the cursor visible.
        if DECTCEM in modes:
            self.cursor.hidden = False

    def reset_mode(self, *modes, **kwargs):
        """Reset (disable) a given list of modes.
        :param list modes: modes to reset -- hopefully, each mode is a
                           constant from :mod:`pyte.modes`.
        """
        # Private mode codes are shifted, to be distinguished from non
        # private ones.
        if kwargs.get("private"):
            modes = [mode << 5 for mode in modes]
            if DECSCNM in modes:
                self.dirty.update(range(self.lines))

        self.mode.difference_update(modes)

        # Lines below follow the logic in :meth:`set_mode`.
        if DECCOLM in modes:
            if self.columns == 132 and self.saved_columns is not None:
                self.resize(columns=self.saved_columns)
                self.saved_columns = None
            self.erase_in_display(2)
            self.cursor_position()

        if DECOM in modes:
            self.cursor_position()

        if DECSCNM in modes:
            for line in self.buffer.values():
                line.default = self.default_char
                for x in line:
                    line[x] = line[x]._replace(reverse=False)

            self.select_graphic_rendition(27)  # -reverse.

        # Hide the cursor.
        if DECTCEM in modes:
            self.cursor.hidden = True

    def define_charset(self, code, mode):
        """Define ``G0`` or ``G1`` charset.
        :param str code: character set code, should be a character
                         from ``"B0UK"``, otherwise ignored.
        :param str mode: if ``"("`` ``G0`` charset is defined, if
                         ``")"`` -- we operate on ``G1``.
        .. warning:: User-defined charsets are currently not supported.
        """
        if code in MAPS:
            if mode == "(":
                self.g0_charset = MAPS[code]
            elif mode == ")":
                self.g1_charset = MAPS[code]

    def shift_in(self):
        """Select ``G0`` character set."""
        self.charset = 0

    def shift_out(self):
        """Select ``G1`` character set."""
        self.charset = 1

    def draw(self, data):
        """Display decoded characters at the current cursor position and
        advances the cursor if :data:`~pyte.modes.DECAWM` is set.
        :param str data: text to display.
        .. versionchanged:: 0.5.0
           Character width is taken into account. Specifically, zero-width
           and unprintable characters do not affect screen state. Full-width
           characters are rendered into two consecutive character containers.
        """
        data = data.translate(
            self.g1_charset if self.charset else self.g0_charset)

        for char in data:
            char_width = wcwidth(char)

            # If this was the last column in a line and auto wrap mode is
            # enabled, move the cursor to the beginning of the next line,
            # otherwise replace characters already displayed with newly
            # entered.
            if self.cursor.x == self.columns:
                if DECAWM in self.mode:
                    self.dirty.add(self.cursor.y)
                    self.carriage_return()
                    self.linefeed()
                elif char_width > 0:
                    self.cursor.x -= char_width

            # If Insert mode is set, new characters move old characters to
            # the right, otherwise terminal is in Replace mode and new
            # characters replace old characters at cursor position.
            if IRM in self.mode and char_width > 0:
                self.insert_characters(char_width)

            line = self.buffer[self.cursor.y]
            if char_width == 1:
                line[self.cursor.x] = self.cursor.attrs._replace(data=char)
            elif char_width == 2:
                # A two-cell character has a stub slot after it.
                line[self.cursor.x] = self.cursor.attrs._replace(data=char)
                if self.cursor.x + 1 < self.columns:
                    line[self.cursor.x + 1] = self.cursor.attrs \
                        ._replace(data="")
            elif char_width == 0 and unicodedata.combining(char):
                # A zero-cell character is combined with the previous
                # character either on this or preceding line.
                if self.cursor.x:
                    last = line[self.cursor.x - 1]
                    normalized = unicodedata.normalize("NFC", last.data + char)
                    line[self.cursor.x - 1] = last._replace(data=normalized)
                elif self.cursor.y:
                    last = self.buffer[self.cursor.y - 1][self.columns - 1]
                    normalized = unicodedata.normalize("NFC", last.data + char)
                    self.buffer[self.cursor.y - 1][self.columns - 1] = \
                        last._replace(data=normalized)
            else:
                break  # Unprintable character or doesn't advance the cursor.

            # .. note:: We can't use :meth:`cursor_forward()`, because that
            #           way, we'll never know when to linefeed.
            if char_width > 0:
                self.cursor.x = min(self.cursor.x + char_width, self.columns)

        self.dirty.add(self.cursor.y)

    def set_title(self, param):
        """Set terminal title.
        .. note:: This is an XTerm extension supported by the Linux terminal.
        """
        self.title = param

    def set_icon_name(self, param):
        """Set icon name.
        .. note:: This is an XTerm extension supported by the Linux terminal.
        """
        self.icon_name = param

    def carriage_return(self):
        """Move the cursor to the beginning of the current line."""
        self.cursor.x = 0

    def index(self):
        """Move the cursor down one line in the same column. If the
        cursor is at the last line, create a new line at the bottom.
        """
        top, bottom = self.margins or Margins(0, self.lines - 1)
        if self.cursor.y == bottom:
            # TODO: mark only the lines within margins?
            self.dirty.update(range(self.lines))
            for y in range(top, bottom):
                self.buffer[y] = self.buffer[y + 1]
            self.buffer.pop(bottom, None)
        else:
            self.cursor_down()

    def reverse_index(self):
        """Move the cursor up one line in the same column. If the cursor
        is at the first line, create a new line at the top.
        """
        top, bottom = self.margins or Margins(0, self.lines - 1)
        if self.cursor.y == top:
            # TODO: mark only the lines within margins?
            self.dirty.update(range(self.lines))
            for y in range(bottom, top, -1):
                self.buffer[y] = self.buffer[y - 1]
            self.buffer.pop(top, None)
        else:
            self.cursor_up()

    def linefeed(self):
        """Perform an index and, if :data:`~pyte.modes.LNM` is set, a
        carriage return.
        """
        self.index()

        if LNM in self.mode:
            self.carriage_return()

    def tab(self):
        """Move to the next tab space, or the end of the screen if there
        aren't anymore left.
        """
        for stop in sorted(self.tabstops):
            if self.cursor.x < stop:
                column = stop
                break
        else:
            column = self.columns - 1

        self.cursor.x = column

    def backspace(self):
        """Move cursor to the left one or keep it in its position if
        it's at the beginning of the line already.
        """
        self.cursor_back()

    def save_cursor(self):
        """Push the current cursor position onto the stack."""
        self.savepoints.append(Savepoint(copy.copy(self.cursor),
                                         self.g0_charset,
                                         self.g1_charset,
                                         self.charset,
                                         DECOM in self.mode,
                                         DECAWM in self.mode))

    def restore_cursor(self):
        """Set the current cursor position to whatever cursor is on top
        of the stack.
        """
        if self.savepoints:
            savepoint = self.savepoints.pop()

            self.g0_charset = savepoint.g0_charset
            self.g1_charset = savepoint.g1_charset
            self.charset = savepoint.charset

            if savepoint.origin:
                self.set_mode(DECOM)
            if savepoint.wrap:
                self.set_mode(DECAWM)

            self.cursor = savepoint.cursor
            self.ensure_hbounds()
            self.ensure_vbounds(use_margins=True)
        else:
            # If nothing was saved, the cursor moves to home position;
            # origin mode is reset. :todo: DECAWM?
            self.reset_mode(DECOM)
            self.cursor_position()

    def insert_lines(self, count=None):
        """Insert the indicated # of lines at line with cursor. Lines
        displayed **at** and below the cursor move down. Lines moved
        past the bottom margin are lost.
        :param count: number of lines to insert.
        """
        count = count or 1
        top, bottom = self.margins or Margins(0, self.lines - 1)

        # If cursor is outside scrolling margins it -- do nothin'.
        if top <= self.cursor.y <= bottom:
            self.dirty.update(range(self.cursor.y, self.lines))
            for y in range(bottom, self.cursor.y - 1, -1):
                if y + count <= bottom and y in self.buffer:
                    self.buffer[y + count] = self.buffer[y]
                self.buffer.pop(y, None)

            self.carriage_return()

    def delete_lines(self, count=None):
        """Delete the indicated # of lines, starting at line with
        cursor. As lines are deleted, lines displayed below cursor
        move up. Lines added to bottom of screen have spaces with same
        character attributes as last line moved up.
        :param int count: number of lines to delete.
        """
        count = count or 1
        top, bottom = self.margins or Margins(0, self.lines - 1)

        # If cursor is outside scrolling margins -- do nothin'.
        if top <= self.cursor.y <= bottom:
            self.dirty.update(range(self.cursor.y, self.lines))
            for y in range(self.cursor.y, bottom + 1):
                if y + count <= bottom:
                    if y + count in self.buffer:
                        self.buffer[y] = self.buffer.pop(y + count)
                else:
                    self.buffer.pop(y, None)

            self.carriage_return()

    def insert_characters(self, count=None):
        """Insert the indicated # of blank characters at the cursor
        position. The cursor does not move and remains at the beginning
        of the inserted blank characters. Data on the line is shifted
        forward.
        :param int count: number of characters to insert.
        """
        self.dirty.add(self.cursor.y)

        count = count or 1
        line = self.buffer[self.cursor.y]
        for x in range(self.columns, self.cursor.x - 1, -1):
            if x + count <= self.columns:
                line[x + count] = line[x]
            line.pop(x, None)

    def delete_characters(self, count=None):
        """Delete the indicated # of characters, starting with the
        character at cursor position. When a character is deleted, all
        characters to the right of cursor move left. Character attributes
        move with the characters.
        :param int count: number of characters to delete.
        """
        self.dirty.add(self.cursor.y)
        count = count or 1

        line = self.buffer[self.cursor.y]
        for x in range(self.cursor.x, self.columns):
            if x + count <= self.columns:
                line[x] = line.pop(x + count, self.default_char)
            else:
                line.pop(x, None)

    def erase_characters(self, count=None):
        """Erase the indicated # of characters, starting with the
        character at cursor position. Character attributes are set
        cursor attributes. The cursor remains in the same position.
        :param int count: number of characters to erase.
        .. note::
           Using cursor attributes for character attributes may seem
           illogical, but if recall that a terminal emulator emulates
           a type writer, it starts to make sense. The only way a type
           writer could erase a character is by typing over it.
        """
        self.dirty.add(self.cursor.y)
        count = count or 1

        line = self.buffer[self.cursor.y]
        for x in range(self.cursor.x,
                       min(self.cursor.x + count, self.columns)):
            line[x] = self.cursor.attrs

    def erase_in_line(self, how=0, private=False):
        """Erase a line in a specific way.
        Character attributes are set to cursor attributes.
        :param int how: defines the way the line should be erased in:
            * ``0`` -- Erases from cursor to end of line, including cursor
              position.
            * ``1`` -- Erases from beginning of line to cursor,
              including cursor position.
            * ``2`` -- Erases complete line.
        :param bool private: when ``True`` only characters marked as
                             eraseable are affected **not implemented**.
        """
        self.dirty.add(self.cursor.y)
        if how == 0:
            interval = range(self.cursor.x, self.columns)
        elif how == 1:
            interval = range(self.cursor.x + 1)
        elif how == 2:
            interval = range(self.columns)

        line = self.buffer[self.cursor.y]
        for x in interval:
            line[x] = self.cursor.attrs

    def erase_in_display(self, how=0, *args, **kwargs):
        """Erases display in a specific way.
        Character attributes are set to cursor attributes.
        :param int how: defines the way the line should be erased in:
            * ``0`` -- Erases from cursor to end of screen, including
              cursor position.
            * ``1`` -- Erases from beginning of screen to cursor,
              including cursor position.
            * ``2`` and ``3`` -- Erases complete display. All lines
              are erased and changed to single-width. Cursor does not
              move.
        :param bool private: when ``True`` only characters marked as
                             eraseable are affected **not implemented**.
        .. versionchanged:: 0.8.1
           The method accepts any number of positional arguments as some
           ``clear`` implementations include a ``;`` after the first
           parameter causing the stream to assume a ``0`` second parameter.
        """
        if how == 0:
            interval = range(self.cursor.y + 1, self.lines)
        elif how == 1:
            interval = range(self.cursor.y)
        elif how == 2 or how == 3:
            interval = range(self.lines)

        self.dirty.update(interval)
        for y in interval:
            line = self.buffer[y]
            for x in line:
                line[x] = self.cursor.attrs

        if how == 0 or how == 1:
            self.erase_in_line(how)

    def set_tab_stop(self):
        """Set a horizontal tab stop at cursor position."""
        self.tabstops.add(self.cursor.x)

    def clear_tab_stop(self, how=0):
        """Clear a horizontal tab stop.
        :param int how: defines a way the tab stop should be cleared:
            * ``0`` or nothing -- Clears a horizontal tab stop at cursor
              position.
            * ``3`` -- Clears all horizontal tab stops.
        """
        if how == 0:
            # Clears a horizontal tab stop at cursor position, if it's
            # present, or silently fails if otherwise.
            self.tabstops.discard(self.cursor.x)
        elif how == 3:
            self.tabstops = set()  # Clears all horizontal tab stops.

    def ensure_hbounds(self):
        """Ensure the cursor is within horizontal screen bounds."""
        self.cursor.x = min(max(0, self.cursor.x), self.columns - 1)

    def ensure_vbounds(self, use_margins=None):
        """Ensure the cursor is within vertical screen bounds.
        :param bool use_margins: when ``True`` or when
                                 :data:`~pyte.modes.DECOM` is set,
                                 cursor is bounded by top and and bottom
                                 margins, instead of ``[0; lines - 1]``.
        """
        if (use_margins or DECOM in self.mode) and self.margins is not None:
            top, bottom = self.margins
        else:
            top, bottom = 0, self.lines - 1

        self.cursor.y = min(max(top, self.cursor.y), bottom)

    def cursor_up(self, count=None):
        """Move cursor up the indicated # of lines in same column.
        Cursor stops at top margin.
        :param int count: number of lines to skip.
        """
        top, _bottom = self.margins or Margins(0, self.lines - 1)
        self.cursor.y = max(self.cursor.y - (count or 1), top)

    def cursor_up1(self, count=None):
        """Move cursor up the indicated # of lines to column 1. Cursor
        stops at bottom margin.
        :param int count: number of lines to skip.
        """
        self.cursor_up(count)
        self.carriage_return()

    def cursor_down(self, count=None):
        """Move cursor down the indicated # of lines in same column.
        Cursor stops at bottom margin.
        :param int count: number of lines to skip.
        """
        _top, bottom = self.margins or Margins(0, self.lines - 1)
        self.cursor.y = min(self.cursor.y + (count or 1), bottom)

    def cursor_down1(self, count=None):
        """Move cursor down the indicated # of lines to column 1.
        Cursor stops at bottom margin.
        :param int count: number of lines to skip.
        """
        self.cursor_down(count)
        self.carriage_return()

    def cursor_back(self, count=None):
        """Move cursor left the indicated # of columns. Cursor stops
        at left margin.
        :param int count: number of columns to skip.
        """
        # Handle the case when we've just drawn in the last column
        # and would wrap the line on the next :meth:`draw()` call.
        if self.cursor.x == self.columns:
            self.cursor.x -= 1

        self.cursor.x -= count or 1
        self.ensure_hbounds()

    def cursor_forward(self, count=None):
        """Move cursor right the indicated # of columns. Cursor stops
        at right margin.
        :param int count: number of columns to skip.
        """
        self.cursor.x += count or 1
        self.ensure_hbounds()

    def cursor_position(self, line=None, column=None):
        """Set the cursor to a specific `line` and `column`.
        Cursor is allowed to move out of the scrolling region only when
        :data:`~pyte.modes.DECOM` is reset, otherwise -- the position
        doesn't change.
        :param int line: line number to move the cursor to.
        :param int column: column number to move the cursor to.
        """
        column = (column or 1) - 1
        line = (line or 1) - 1

        # If origin mode (DECOM) is set, line number are relative to
        # the top scrolling margin.
        if self.margins is not None and DECOM in self.mode:
            line += self.margins.top

            # Cursor is not allowed to move out of the scrolling region.
            if not self.margins.top <= line <= self.margins.bottom:
                return

        self.cursor.x = column
        self.cursor.y = line
        self.ensure_hbounds()
        self.ensure_vbounds()

    def cursor_to_column(self, column=None):
        """Move cursor to a specific column in the current line.
        :param int column: column number to move the cursor to.
        """
        self.cursor.x = (column or 1) - 1
        self.ensure_hbounds()

    def cursor_to_line(self, line=None):
        """Move cursor to a specific line in the current column.
        :param int line: line number to move the cursor to.
        """
        self.cursor.y = (line or 1) - 1

        # If origin mode (DECOM) is set, line number are relative to
        # the top scrolling margin.
        if DECOM in self.mode:
            self.cursor.y += self.margins.top

            # FIXME: should we also restrict the cursor to the scrolling
            # region?

        self.ensure_vbounds()

    def bell(self, *args):
        """Bell stub -- the actual implementation should probably be
        provided by the end-user.
        """

    def alignment_display(self):
        """Fills screen with uppercase E's for screen focus and alignment."""
        self.dirty.update(range(self.lines))
        for y in range(self.lines):
            for x in range(self.columns):
                self.buffer[y][x] = self.buffer[y][x]._replace(data="E")

    def select_graphic_rendition(self, *attrs):
        """Set display attributes.
        :param list attrs: a list of display attributes to set.
        """
        replace = {}

        # Fast path for resetting all attributes.
        if not attrs or attrs == (0, ):
            self.cursor.attrs = self.default_char
            return
        else:
            attrs = list(reversed(attrs))

        while attrs:
            attr = attrs.pop()
            if attr == 0:
                # Reset all attributes.
                replace.update(self.default_char._asdict())
            elif attr in g.FG_ANSI:
                replace["fg"] = g.FG_ANSI[attr]
            elif attr in g.BG:
                replace["bg"] = g.BG_ANSI[attr]
            elif attr in g.TEXT:
                attr = g.TEXT[attr]
                replace[attr[1:]] = attr.startswith("+")
            elif attr in g.FG_AIXTERM:
                replace.update(fg=g.FG_AIXTERM[attr])
            elif attr in g.BG_AIXTERM:
                replace.update(bg=g.BG_AIXTERM[attr])
            elif attr in (g.FG_256, g.BG_256):
                key = "fg" if attr == g.FG_256 else "bg"
                try:
                    n = attrs.pop()
                    if n == 5:    # 256.
                        m = attrs.pop()
                        replace[key] = g.FG_BG_256[m]
                    elif n == 2:  # 24bit.
                        # This is somewhat non-standard but is nonetheless
                        # supported in quite a few terminals. See discussion
                        # here https://gist.github.com/XVilka/8346728.
                        replace[key] = "{0:02x}{1:02x}{2:02x}".format(
                            attrs.pop(), attrs.pop(), attrs.pop())
                except IndexError:
                    pass

        self.cursor.attrs = self.cursor.attrs._replace(**replace)

    def report_device_attributes(self, mode=0, **kwargs):
        """Report terminal identity.
        .. versionadded:: 0.5.0
        .. versionchanged:: 0.7.0
           If ``private`` keyword argument is set, the method does nothing.
           This behaviour is consistent with VT220 manual.
        """
        # We only implement "primary" DA which is the only DA request
        # VT102 understood, see ``VT102ID`` in ``linux/drivers/tty/vt.c``.
        if mode == 0 and not kwargs.get("private"):
            self.write_process_input(CtrlCodes.CSI + "?6c")

    def report_device_status(self, mode):
        """Report terminal status or cursor position.
        :param int mode: if 5 -- terminal status, 6 -- cursor position,
                         otherwise a noop.
        .. versionadded:: 0.5.0
        """
        if mode == 5:    # Request for terminal status.
            self.write_process_input(CtrlCodes.CSI + "0n")
        elif mode == 6:  # Request for cursor position.
            x = self.cursor.x + 1
            y = self.cursor.y + 1

            # "Origin mode (DECOM) selects line numbering."
            if DECOM in self.mode:
                y -= self.margins.top
            self.write_process_input(CtrlCodes.CSI + "{0};{1}R".format(y, x))

    def write_process_input(self, data):
        """Write data to the process running inside the terminal.
        By default is a noop.
        :param str data: text to write to the process ``stdin``.
        .. versionadded:: 0.5.0
        """

    def debug(self, *args, **kwargs):
        """Endpoint for unrecognized escape sequences.
        By default is a noop.
        """


class DiffScreen(Screen):
    """
    A screen subclass, which maintains a set of dirty lines in its
    :attr:`dirty` attribute. The end user is responsible for emptying
    a set, when a diff is applied.
    .. deprecated:: 0.7.0
       The functionality contained in this class has been merged into
       :class:`~pyte.screens.Screen` and will be removed in 0.8.0.
       Please update your code accordingly.
    """
    def __init__(self, *args, **kwargs):
        warnings.warn(
            "The functionality of ``DiffScreen` has been merged into "
            "``Screen`` and will be removed in 0.8.0. Please update "
            "your code accordingly.", DeprecationWarning)

        super(DiffScreen, self).__init__(*args, **kwargs)


History = namedtuple("History", "top bottom ratio size position")


class HistoryScreen(Screen):
    """A :class:~`pyte.screens.Screen` subclass, which keeps track
    of screen history and allows pagination. This is not linux-specific,
    but still useful; see page 462 of VT520 User's Manual.
    :param int history: total number of history lines to keep; is split
                        between top and bottom queues.
    :param int ratio: defines how much lines to scroll on :meth:`next_page`
                      and :meth:`prev_page` calls.
    .. attribute:: history
       A pair of history queues for top and bottom margins accordingly;
       here's the overall screen structure::
            [ 1: .......]
            [ 2: .......]  <- top history
            [ 3: .......]
            ------------
            [ 4: .......]  s
            [ 5: .......]  c
            [ 6: .......]  r
            [ 7: .......]  e
            [ 8: .......]  e
            [ 9: .......]  n
            ------------
            [10: .......]
            [11: .......]  <- bottom history
            [12: .......]
    .. note::
       Don't forget to update :class:`~pyte.streams.Stream` class with
       appropriate escape sequences -- you can use any, since pagination
       protocol is not standardized, for example::
           Stream.escape["N"] = "next_page"
           Stream.escape["P"] = "prev_page"
    """
    _wrapped = set(Stream.events)
    _wrapped.update(["next_page", "prev_page"])

    def __init__(self, columns, lines, history=100, ratio=.5):
        self.history = History(deque(maxlen=history),
                               deque(maxlen=history),
                               float(ratio),
                               history,
                               history)

        super(HistoryScreen, self).__init__(columns, lines)

    def _make_wrapper(self, event, handler):
        def inner(*args, **kwargs):
            self.before_event(event)
            result = handler(*args, **kwargs)
            self.after_event(event)
            return result
        return inner

    def __getattribute__(self, attr):
        value = super(HistoryScreen, self).__getattribute__(attr)
        if attr in HistoryScreen._wrapped:
            return HistoryScreen._make_wrapper(self, attr, value)
        else:
            return value

    def before_event(self, event):
        """Ensure a screen is at the bottom of the history buffer.
        :param str event: event name, for example ``"linefeed"``.
        """
        if event not in ["prev_page", "next_page"]:
            while self.history.position < self.history.size:
                self.next_page()

    def after_event(self, event):
        """Ensure all lines on a screen have proper width (:attr:`columns`).
        Extra characters are truncated, missing characters are filled
        with whitespace.
        :param str event: event name, for example ``"linefeed"``.
        """
        if event in ["prev_page", "next_page"]:
            for line in self.buffer.values():
                for x in line:
                    if x > self.columns:
                        line.pop(x)

        # If we're at the bottom of the history buffer and `DECTCEM`
        # mode is set -- show the cursor.
        self.cursor.hidden = not (
            self.history.position == self.history.size and
            DECTCEM in self.mode
        )

    def _reset_history(self):
        self.history.top.clear()
        self.history.bottom.clear()
        self.history = self.history._replace(position=self.history.size)

    def reset(self):
        """Overloaded to reset screen history state: history position
        is reset to bottom of both queues;  queues themselves are
        emptied.
        """
        super(HistoryScreen, self).reset()
        self._reset_history()

    def erase_in_display(self, how=0, *args, **kwargs):
        """Overloaded to reset history state."""
        super(HistoryScreen, self).erase_in_display(how, *args, **kwargs)

        if how == 3:
            self._reset_history()

    def index(self):
        """Overloaded to update top history with the removed lines."""
        top, bottom = self.margins or Margins(0, self.lines - 1)

        if self.cursor.y == bottom:
            self.history.top.append(self.buffer[top])

        super(HistoryScreen, self).index()

    def reverse_index(self):
        """Overloaded to update bottom history with the removed lines."""
        top, bottom = self.margins or Margins(0, self.lines - 1)

        if self.cursor.y == top:
            self.history.bottom.append(self.buffer[bottom])

        super(HistoryScreen, self).reverse_index()

    def prev_page(self):
        """Move the screen page up through the history buffer. Page
        size is defined by ``history.ratio``, so for instance
        ``ratio = .5`` means that half the screen is restored from
        history on page switch.
        """
        if self.history.position > self.lines and self.history.top:
            mid = min(len(self.history.top),
                      int(math.ceil(self.lines * self.history.ratio)))

            self.history.bottom.extendleft(
                self.buffer[y]
                for y in range(self.lines - 1, self.lines - mid - 1, -1))
            self.history = self.history._replace(position=self.history.position - mid)

            for y in range(self.lines - 1, mid - 1, -1):
                self.buffer[y] = self.buffer[y - mid]
            for y in range(mid - 1, -1, -1):
                self.buffer[y] = self.history.top.pop()

            self.dirty = set(range(self.lines))

    def next_page(self):
        """Move the screen page down through the history buffer."""
        if self.history.position < self.history.size and self.history.bottom:
            mid = min(len(self.history.bottom),
                      int(math.ceil(self.lines * self.history.ratio)))

            self.history.top.extend(self.buffer[y] for y in range(mid))
            self.history = self.history._replace(position=self.history.position + mid)

            for y in range(self.lines - mid):
                self.buffer[y] = self.buffer[y + mid]
            for y in range(self.lines - mid, self.lines):
                self.buffer[y] = self.history.bottom.popleft()

            self.dirty = set(range(self.lines))


class DebugEvent(namedtuple("Event", "name args kwargs")):
    """Event dispatched to :class:`~pyte.screens.DebugScreen`.
    .. warning::
       This is developer API with no backward compatibility guarantees.
       Use at your own risk!
    """
    @staticmethod
    def from_string(line):
        return DebugEvent(*json.loads(line))

    def __str__(self):
        return json.dumps(self)

    def __call__(self, screen):
        """Execute this event on a given ``screen``."""
        return getattr(screen, self.name)(*self.args, **self.kwargs)


class DebugScreen(object):
    r"""A screen which dumps a subset of the received events to a file.
    >>> import io
    >>> with io.StringIO() as buf:
    ...     stream = Stream(DebugScreen(to=buf))
    ...     stream.feed("\x1b[1;24r\x1b[4l\x1b[24;1H\x1b[0;10m")
    ...     print(buf.getvalue())
    ...
    ... # doctest: +NORMALIZE_WHITESPACE
    ["set_margins", [1, 24], {}]
    ["reset_mode", [4], {}]
    ["cursor_position", [24, 1], {}]
    ["select_graphic_rendition", [0, 10], {}]
    :param file to: a file-like object to write debug information to.
    :param list only: a list of events you want to debug (empty by
                      default, which means -- debug all events).
    .. warning::
       This is developer API with no backward compatibility guarantees.
       Use at your own risk!
    """
    def __init__(self, to=sys.stderr, only=()):
        self.to = to
        self.only = only

    def only_wrapper(self, attr):
        def wrapper(*args, **kwargs):
            self.to.write(str(DebugEvent(attr, args, kwargs)))
            self.to.write(str(os.linesep))

        return wrapper

    def __getattribute__(self, attr):
        if attr not in Stream.events:
            return super(DebugScreen, self).__getattribute__(attr)
        elif not self.only or attr in self.only:
            return self.only_wrapper(attr)
        else:
            return lambda *args, **kwargs: None