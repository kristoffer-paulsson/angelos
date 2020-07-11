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
import os

dirname = os.path.abspath(os.curdir)

SPEC = """# -*- mode: python ; coding: utf-8 -*-

import os
import sys
import glob

block_cipher = None
path = os.path.abspath(".")
bin_path = os.path.join(path, 'bin', 'angelos')
lib_path = os.path.join(path, 'lib', 'angelos')
sys.path.insert(0, lib_path)


def angelos_import(path):
    pys = []
    for file in glob.iglob(path + "/**/*", recursive=True):
        if file.endswith(".pyx") or file.endswith(".pxd"):
            pys.append(file[4:-4].replace("/", "."))
    return pys

extra_import = [  # Internal python packages
    "asyncio", "dataclasses", "logging.config", "uuid", "fcntl", "csv"

    ] + ["asyncssh", "msgpack", "plyer",
    "plyer.platforms", "plyer.platforms.macosx",
    "plyer.platforms.macosx.uniqueid"
    ] + angelos_import("lib/libangelos") + angelos_import("lib/angelos")

a = Analysis([bin_path],
             pathex=[path],
             binaries=[],
             datas=[],
             hiddenimports=extra_import,
             hookspath=[],
             runtime_hooks=[],
             excludes=["_tkinter", "Tkinter", "enchant", "twisted"],
             win_no_prefer_redirects=False,
             win_private_assemblies=False,
             cipher=block_cipher,
             noarchive=False)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)
exe = EXE(pyz,
          a.scripts,
          a.binaries,
          a.zipfiles,
          a.datas,
          [],
          name="angelos",
          debug=False,
          bootloader_ignore_signals=False,
          strip=False,
          upx=True,
          upx_exclude=[],
          runtime_tmpdir=None,
          console=False)
# exe = COLLECT(
#    exe,
#    Tree(path),
#    a.binaries,
#    a.zipfiles,
#    a.datas,
#    strip=None,
#    upx=True,
#    name='angelos')
"""  # noqa E501

path_spec = os.path.join(dirname, 'angelos.spec')
# os.remove(path_spec)
with open(path_spec, 'w') as f:
    f.write(SPEC)
