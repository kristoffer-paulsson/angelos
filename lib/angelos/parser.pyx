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
"""Server argument parser."""
import argparse

from libangelos.const import Const


class Parser:
    """Argument parsing class that can be loaded in a container."""

    def __init__(self):
        """Initialize parser."""
        parser = self.parser()
        self.args = parser.parse_args()

    def parser(self):
        """Argument parser configuration."""
        parser = argparse.ArgumentParser()
        parser.add_argument(
            "-l",
            "--listen",
            choices=Const.OPT_LISTEN,
            dest="listen",
            default="localhost",
            help="listen to a network interface. (localhost)",
        )
        parser.add_argument(
            "-p",
            "--port",
            dest="port",
            default=22,
            type=int,
            help="listen to a network port. (22)",
        )
        parser.add_argument(
            "-d",
            "--daemon",
            choices=["start", "stop", "resume", "suspend"],
            dest="daemon",
            default=None,
            help="run server as a daemon.",
        )
        return parser
