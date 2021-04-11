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
"""TTY terminal emulator and shell with commands as protocol handler."""

# Pyte VT100 terminal https://github.com/selectel/pyte
# $ click_ Command Line Interface Creation Kit https://github.com/pallets/click/
# cmd2 https://github.com/python-cmd2/cmd2
# https://github.com/ronf/asyncssh/blob/875330da4bb0322d872f702dbb1f44c7e6137c48/asyncssh/editor.py#L273
# https://espterm.github.io/docs/VT100%20escape%20codes.html

from angelos.net.base import Handler, StateMode, Protocol


TTY_SEQ = r"""(\x1B\[[\x40-\x7E]*[\x20-\x2F]|\x1B[\x30-\x7E]*[\x20-\x2F]|[\x00-\x1F])"""


"""# Change terminal window size from python.
import sys
sys.stdout.write("\x1b[8;{rows};{cols}t".format(rows=32, cols=100))
"""

"""# Signal handlers.
def init_signals(self) -> None:
        # Set up signals through the event loop API.

        self.loop.add_signal_handler(signal.SIGQUIT, self.handle_quit,
                                     signal.SIGQUIT, None)

        self.loop.add_signal_handler(signal.SIGTERM, self.handle_exit,
                                     signal.SIGTERM, None)

        self.loop.add_signal_handler(signal.SIGINT, self.handle_quit,
                                     signal.SIGINT, None)

        self.loop.add_signal_handler(signal.SIGWINCH, self.handle_winch,
                                     signal.SIGWINCH, None)

        self.loop.add_signal_handler(signal.SIGUSR1, self.handle_usr1,
                                     signal.SIGUSR1, None)

        self.loop.add_signal_handler(signal.SIGABRT, self.handle_abort,
                                     signal.SIGABRT, None)

        # Don't let SIGTERM and SIGUSR1 disturb active requests
        # by interrupting system calls
        signal.siginterrupt(signal.SIGTERM, False)
        signal.siginterrupt(signal.SIGUSR1, False)
"""

"""# Check for terminal session.
sys.stdout.isatty()
os.isatty(fd)
os.get_terminal_size(fd=)
"""



AUTHENTICATION_VERSION = b"tty-0.1"


class TTYHandler(Handler):
    LEVEL = 1
    RANGE = 1

    ST_VERSION = 0x01

    def __init__(self, manager: Protocol):
        Handler.__init__(self, manager, states={
            self.ST_VERSION: (StateMode.MEDIATE, AUTHENTICATION_VERSION),
        })


class TTYClient(TTYHandler):

    def __init__(self, manager: Protocol):
        TTYHandler.__init__(self, manager)


class TTYServer(TTYHandler):

    def __init__(self, manager: Protocol):
        TTYHandler.__init__(self, manager)
