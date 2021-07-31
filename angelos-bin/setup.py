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
import sys
from configparser import ConfigParser
from pathlib import Path

from Cython.Build import cythonize
from Cython.Compiler.Options import get_directive_defaults
from angelos.meta.setup import LibraryScanner, Vendor, VendorCompileNacl
from angelos.meta.setup.vendor import VendorDownload
from setuptools import setup, find_namespace_packages
from setuptools.command.develop import develop
from setuptools.command.install import install
from wheel.bdist_wheel import bdist_wheel


class CustomDevelop(develop):
    """Custom steps for develop command."""

    def run(self):
        self.run_command("vendor")
        develop.run(self)


class CustomInstall(install):
    """Preparations and adaptions of building the app."""

    def run(self):
        """Carry out preparations and adaptions."""
        self.run_command("vendor")
        install.run(self)


class CustomBDistWheel(bdist_wheel):
    """Preparations and adaptions of building the app."""

    def run(self):
        """Carry out preparations and adaptions."""
        self.run_command("vendor")
        bdist_wheel.run(self)


NAME = "angelos.bin"
config = ConfigParser()
config.read(Path(__file__).absolute().parents[1].joinpath("project.ini"))
VERSION = config.get("common", "version")
RELEASE = config.get("common", "release")
PYTHON = config.get("common", "python")

directive_defaults = get_directive_defaults()
directive_defaults['language_level'] = config.getint("cython", "language_level")
directive_defaults['linetrace'] = config.getboolean("cython", "linetrace")

scan = {
    "glob": [
        str(Path("angelos/bin/*.pyx")),
        str(Path("angelos/bin/mac/*.pyx")) if sys.platform == "darwin" else str(Path("angelos/bin/win/*.pyx")) if sys.platform == "win32" else str(Path("angelos/bin/nix/*.pyx")),
    ],
    "extra": {
        "angelos.bin.nacl": {
            "include_dirs": [str(Path("tarball/libsodium/libsodium/include").absolute())],
            "extra_compile_args": ["-static"],
            "extra_objects": [
                str(Path("tarball/libsodium/libsodium/x64/Release/v142/static/libsodium.lib").absolute())
            ],
            "export_symbols": [
                "crypto_box_beforenm", "crypto_sign_bytes", "crypto_secretbox_open", "crypto_scalarmult_base",
                "crypto_aead_xchacha20poly1305_ietf_keybytes", "crypto_kx_client_session_keys"
            ],
        } if sys.platform == "win32" else {
            "extra_objects": [str(Path("usr/local/lib/libsodium.a"))],
            "include_dirs": [str(Path("usr/local/include").absolute())]  # CentOS specific only (?)
        },
    },
    "basic": {
        "extra_compile_args": ["-DCYTHON_TRACE_NOGIL=1" if config.getboolean("cython", "linetrace") else ""],
    }
}

config = {
    "name": NAME,
    "version": VERSION,
    "license": "MIT",
    "cmdclass": {
        "develop": CustomDevelop,
        "install": CustomInstall,
        "bdist_wheel": CustomBDistWheel,
        "vendor": Vendor,
    },
    "command_options": {
        "vendor": {
            "base_dir": ("", str(Path(__file__).parent.absolute())),
            "compile": ("", [
                {
                    "class": VendorDownload,
                    "name": "libsodium",
                    "download": "https://download.libsodium.org/libsodium/releases/libsodium-1.0.18-stable-msvc.zip",
                    "local": "libsodium-1.0.18-msvc.zip",
                    "internal": "libsodium",
                    "check": str(Path("tarball/libsodium/libsodium/x64/Release/v142/static/libsodium.lib").absolute()),
                } if sys.platform == "win32" else {
                    "class": VendorCompileNacl,
                    "name": "libsodium",
                    "download": "https://download.libsodium.org/libsodium/releases/libsodium-1.0.18-stable.tar.gz",
                    "local": "libsodium-1.0.18.tar.gz",
                    "internal": "libsodium-stable",
                    "check": str(Path("usr/local/lib/libsodium.a")),
                }
            ]),
        }
    },
    "classifiers": [
          "Development Status :: 4 - Beta",
          "Intended Audience :: Developers",
          "License :: OSI Approved :: MIT License",
          "Programming Language :: Cython",
          "Topic :: Security :: Cryptography",
    ],
    # "data_files": [("", [str(p) for p in Path("tarball").glob("*.tar.gz")])],
    "package_dir": {"": "src"},
    "packages": find_namespace_packages(where="src", include=["angelos.*"]),
    "namespace_packages": ["angelos"],
    "ext_modules": cythonize(
        LibraryScanner(str(Path("src")), **scan).scan(),
        build_dir="build",
    ),
    "python_requires": PYTHON,
}

setup(**config)