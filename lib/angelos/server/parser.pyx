# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Server argument parser."""
import argparse

from ..const import Const


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
