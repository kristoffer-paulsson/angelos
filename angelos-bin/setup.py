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
from pathlib import Path

from Cython.Build import cythonize
from angelos.meta.setup.vendor import VendorDownload
from setuptools import setup, find_namespace_packages
from setuptools.command.develop import develop
from setuptools.command.install import install
from wheel.bdist_wheel import bdist_wheel

from angelos.meta.setup import LibraryScanner, Vendor, VendorCompileNacl


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
VERSION = "1.0.0b1"
RELEASE = ""

scan = {
    "glob": [
        str(Path("angelos/bin/*.pyx"))
    ],
    "extra": {
        "angelos.bin.nacl": {
            "libraries": [str(Path("libsodium"))],
            "library_dirs": [str(Path("tarball/libsodium/libsodium/x64/Release/v142/static"))],
            "include_dirs": [str(Path("tarball/libsodium/libsodium/include").absolute())],
            "language": "c++"
        } if sys.platform == "win32" else {
            "extra_objects": [str(Path("usr/local/lib/libsodium.a"))],
            "include_dirs": [str(Path("usr/local/include").absolute())]  # CentOS specific only (?)
        }
    },
    "basic": {
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
                    "check": str(Path("tarball/libsodium/libsodium/x64/Release/v142/static/libsodium.lib")),
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
        compiler_directives={
            "language_level": 3,
        }
    ),
}

setup(**config)