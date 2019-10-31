"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import os

dirname = os.path.abspath(os.curdir)

SPEC = """# -*- mode: python ; coding: utf-8 -*-

import os
import sys
import glob
from kivy.tools.packaging.pyinstaller_hooks import (
    get_deps_all, hookspath, runtime_hooks)
import kivymd

block_cipher = None
path = os.path.abspath(".")
bin_path = os.path.join(path, 'bin', 'logo')
lib_path = os.path.join(path, 'lib', 'angelos')
sys.path.insert(0, lib_path)
kivymd_path = os.path.dirname(kivymd.__file__)
sys.path.insert(0, kivymd_path)

# from kivy_deps.sdl2 import dep_bins as sdl2_dep_bins
# from kivy_deps.glew import dep_bins as glew_dep_bins
from kivymd import hooks_path as kivymd_hooks_path

kivydeps = get_deps_all()

def angelos_import(path):
    pys = []
    for file in glob.iglob(path + "/**/*", recursive=True):
        if file.endswith(".pyx") or file.endswith(".pxd"):
            pys.append(file[4:-4].replace("/", "."))
    return pys

extra_import = [  # Internal python packages
    "asyncio", "dataclasses", "logging.config"
    ] + [  # Third party packages
    "kivymd.toast", "asyncssh", "msgpack", "plyer", "libnacl", "libnacl.sign",
    "libnacl.secret", "kivymd.vendor", "kivymd.vendor.circularTimePicker",
    "plyer.platforms", "plyer.platforms.macosx", "macos_keychain", "macos_keychain.main"
    "plyer.platforms.macosx.keystore", "keyring"
    ] + angelos_import("lib/libangelos") + angelos_import("lib/logo")

a = Analysis([bin_path],
             pathex=[kivymd_path],
             binaries=kivydeps["binaries"] + [],
             datas=[],
             hiddenimports=kivydeps["hiddenimports"] + extra_import,
             hookspath=hookspath() + [kivymd_hooks_path],
             runtime_hooks=runtime_hooks() + [],
             excludes=kivydeps["excludes"] + ["_tkinter", "Tkinter", "enchant", "twisted"],
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
          name="logo",
          debug=False,
          bootloader_ignore_signals=False,
          strip=False,
          upx=True,
          upx_exclude=[],
          runtime_tmpdir=None,
          console=False )
app = BUNDLE(exe,
             name="Logo.app",
             icon="assets/icons/dove.icns",
             bundle_identifier=None,
             info_plist={
                'NSHighResolutionCapable': 'True'
                })
"""  # noqa E501

path_spec = os.path.join(dirname, 'logo.spec')
# os.remove(path_spec)
with open(path_spec, 'w') as f:
    f.write(SPEC)
