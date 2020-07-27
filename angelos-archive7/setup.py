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
from pathlib import Path

from Cython.Build import cythonize
from angelos.meta.setup import LibraryScanner
from setuptools import setup, find_namespace_packages

NAME = "angelos.archive"
VERSION = "1.0.0b1"
RELEASE = ""

scan = {
    "glob": [
        "angelos/archive7/*.pyx"
    ],
    "extra": {
    },
    "basic": {
    }
}

config = {
    "name": NAME,
    "version": VERSION,
    "classifiers": [
          "Development Status :: 4 - Beta",
          "Intended Audience :: Developers",
          "Intended Audience :: End Users/Desktop",
          "Intended Audience :: System Administrators",
          "License :: OSI Approved :: MIT License",
          "Programming Language :: Cython",
          "Topic :: Security",
          "Topic :: System :: Archiving",
          "Topic :: Utilities"
    ],
    # "install_requires": ["angelos.common", "angelos.bin"],
    "package_dir": {"": "src"},
    "packages": find_namespace_packages(where="src", include=["angelos.*"]),
    "namespace_packages": ["angelos"],
    "ext_modules": cythonize(
        LibraryScanner(str(Path("./src")), **scan).scan(),
        build_dir="build",
        compiler_directives={
            "language_level": 3,
        }
    ),
}

setup(**config)