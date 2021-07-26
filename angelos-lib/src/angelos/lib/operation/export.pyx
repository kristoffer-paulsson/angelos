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
"""Module string"""
import base64
import re

from angelos.lib.operation.operation import Operation
from angelos.lib.policy.portfolio import PortfolioPolicy, Portfolio

REGEX = r"----[\n\r]([a-zA-Z0-9+/\n\r]+={0,3})[\n\r]----"


class ExportImportOperation(Operation):
    """Operation for exporting and importing portfolio data."""

    @staticmethod
    def text_imp(data: str) -> Portfolio:
        """Import portfolio in text file format."""
        match = re.findall(REGEX, data, re.MULTILINE)
        if len(match) != 1:
            return None
        data = match[0]
        return PortfolioPolicy.imports(base64.b64decode(data))

    @staticmethod
    def text_exp(portfolio: Portfolio) -> str:
        """Export portfolio to text file format."""
        return ExportImportOperation.exporter("Portfolio", portfolio)

    @staticmethod
    def exporter(name: str, portfolio: Portfolio):
        output = ExportImportOperation.headline(name, "(Begin)")
        data = base64.b64encode(PortfolioPolicy.exports(portfolio)).decode(
            "utf-8"
        )
        output += (
            "\n"
            + "\n".join([data[i:i + 79] for i in range(0, len(data), 79)])
            + "\n"
        )
        output += ExportImportOperation.headline(name, "(End)")
        return output

    @staticmethod
    def headline(title: str, filler: str = ""):
        title = " " + title + " " + filler + " "
        line = "-" * 79
        offset = int(79 / 2 - len(title) / 2)
        return line[:offset] + title + line[offset + len(title):]
