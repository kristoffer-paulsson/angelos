"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import os

dirname = os.path.abspath(os.curdir)
hidden_imports = [
    'uuid', 'pathlib', 'angelos.archive.archive7', 'angelos.ioc',
    'angelos.utils', 'angelos.error', 'angelos.archive.conceal', 'fcntl']

SPEC = """# -*- mode: python -*-

block_cipher = None


a = Analysis(['bin/ar7'],
             pathex=['{pathex:}'],
             binaries=[],
             datas=[],
             hiddenimports=['{hidden_imports:}'],
             hookspath=[],
             runtime_hooks=[],
             excludes=[],
             win_no_prefer_redirects=False,
             win_private_assemblies=False,
             cipher=block_cipher,
             noarchive=False)
pyz = PYZ(a.pure, a.zipped_data,
             cipher=block_cipher)
exe = EXE(pyz,
          a.scripts,
          a.binaries,
          a.zipfiles,
          a.datas,
          [],
          name='ar7',
          debug=False,
          bootloader_ignore_signals=False,
          strip=False,
          upx=True,
          runtime_tmpdir=None,
          console=True )
""".format(
    pathex=dirname,
    hidden_imports="', '".join(hidden_imports)
)

with open(os.path.join(dirname, 'ar7.spec'), 'w') as f:
    f.write(SPEC)
