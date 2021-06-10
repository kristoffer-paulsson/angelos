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

NAME = "angelos.base"
VERSION = "1.0.0a1"
RELEASE = ""

scan = {
    "glob": [
        str(Path("angelos/base/*.pyx"))
    ],
    "extra": {
    },
    "basic": {
    }
}

config = {
    "name": NAME,
    "version": VERSION,
    "license": "MIT",
    "classifiers": [
          "Development Status :: 2 - Pre-Alpha",
          "Intended Audience :: Developers",
          "License :: OSI Approved :: MIT License",
          "Programming Language :: Cython",
    ],
    "install_requires": [],
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
    "python_requires": ">=3.6, <4",
}

setup(**config)