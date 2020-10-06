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
"""Utilities for working with packaging."""
import os
import re

INDEX_REGEX = """(?:##########  ([A-Z0-9_]*)(?<!_END)  ##########)"""
CLIP_REGEX = """(?s)(?<=##########  {0}  ##########).*?(?=##########  {0}_END  ##########)"""


class ScriptIndexer:
    """Utility that scans after scriptlets in a directory of scripts and index them."""

    def __init__(self):
        self.__regex = INDEX_REGEX
        self.__index = dict()

    def walk(self, path: str) -> int:
        """Walk all files and directories at given path."""
        hits = 0

        for root, _, files in os.walk(path):
            for file in files:
                filepath = os.path.join(root, file)
                with open(filepath) as script:
                    for hit in re.finditer(self.__regex, script.read()):
                        ingredient = hit.group(1)
                        if ingredient in self.__index.keys():
                            raise ValueError("Duplicate script! %s" % ingredient)
                        self.__index[ingredient] = filepath
                        hits += 1

        return hits

    @property
    def index(self) -> dict:
        """Access to the index dictionary."""
        return self.__index


class ScriptScissor:
    """Utility to clip and stitch scripts by recipe."""

    def __init__(self, index: dict):
        self.__clip_template = CLIP_REGEX
        self.__index = index

    def clip(self, ingredient: str) -> str:
        """Copy snippet from script."""
        if ingredient not in self.__index.keys():
            raise ValueError("The following snippet not in index! %s" % ingredient)

        with open(self.__index[ingredient]) as script:
            match = re.search(self.__clip_template.format(ingredient), script.read())
            if match:
                return match.group(0)
            else:
                raise ValueError("Snippet not found in script! %s" % ingredient)

    def stitch(self, recipe: list) -> str:
        """Stitch a new script based on recipe."""
        script = ""
        for ingredient in recipe:
            script += self.clip(ingredient)

        return script
