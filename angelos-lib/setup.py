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

NAME = "angelos.lib"
VERSION = "1.0.0b1"
RELEASE = ""

scan = {
    "glob": [
        str(Path("angelos/lib/*.pyx")),
        str(Path("angelos/lib/**/*.pyx"))
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
        "Environment :: No Input/Output (Daemon)",
        "Framework :: AsyncIO",
        "Intended Audience :: Developers",
        "Intended Audience :: Information Technology",
        "Intended Audience :: Religion",
        "Intended Audience :: Telecommunications Industry",
        "License :: OSI Approved :: MIT License",
        # "Programming Language :: C",
        "Programming Language :: Cython",
        "Programming Language :: Python :: 3.7",
        "Topic :: Communications :: Chat",
        "Topic :: Communications :: Email",
        "Topic :: Communications :: File Sharing",
        "Topic :: Documentation",
        "Topic :: Internet",
        "Topic :: Religion",
        "Topic :: Security",
        "Topic :: System :: Archiving",
        "Topic :: Utilities",
    ],
    "install_requires": [
        # "angelos.document", "angelos.common", "angelos.bin", "angelos.archive7",
        "plyer", "asyncssh", "msgpack"],
    "package_dir": {"": "src"},
    "packages": find_namespace_packages(where="src", include=["angelos.*"]),
    "namespace_packages": ["angelos"],
    "ext_modules": cythonize(
        LibraryScanner(str(Path("./src")), **scan).scan(),
        build_dir="build",
        compiler_directives={
            "language_level": 3,
            "linetrace": True
        }
    ),
    "python_requires": ">=3.6, <4",
}

setup(**config)

