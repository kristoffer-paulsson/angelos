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
from pathlib import PurePath

from angelos.lib.const import Const


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
            default=None,
            help="listen to a network interface. (localhost)",
        )
        parser.add_argument(
            "-p",
            "--port",
            dest="port",
            default=None,
            type=int,
            help="listen to a network port. (22)",
        )
        parser.add_argument(
            "config",
            nargs="?",
            default=False,
            type=bool,
            help="Print configuration",
        )
        parser.add_argument(
            "-d",
            "--daemon",
            choices=["start", "stop", "restart"],
            dest="daemon",
            default=None,
            help="Run server as background process.",
        )
        parser.add_argument(
            "--root-dir",
            dest="root_dir",
            default=None,
            type=PurePath,
            help="Server root directory. (/opt/angelos)",
        )
        parser.add_argument(
            "--run-dir",
            dest="run_dir",
            default=None,
            type=PurePath,
            help="Runtime directory. (/run/angelos)",
        )
        parser.add_argument(
            "--state-dir",
            dest="state_dir",
            default=None,
            type=PurePath,
            help="Server state directory. (/var/lib/angelos)",
        )
        parser.add_argument(
            "--logs-dir",
            dest="logs_dir",
            default=None,
            type=PurePath,
            help="Logs directory. (/var/log/angelos)",
        )
        parser.add_argument(
            "--conf-dir",
            dest="conf_dir",
            default=None,
            help="Configuration directory. (/etc/angelos)",
        )
        return parser
