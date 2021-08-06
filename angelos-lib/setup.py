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
from configparser import ConfigParser
from pathlib import Path

from Cython.Build import cythonize
from Cython.Compiler.Options import get_directive_defaults
from angelostools.pyxscanner import PyxScanner
from setuptools import setup, find_namespace_packages

NAME = "angelos.lib"
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
        str(Path("angelos/lib/*.pyx")),
        str(Path("angelos/lib/**/*.pyx"))
    ],
    "extra": {
    },
    "basic": {
        "extra_compile_args": ["-DCYTHON_TRACE_NOGIL=1" if config.getboolean("cython", "linetrace") else ""],
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
        PyxScanner(str(Path("./src")), **scan).scan(),
        build_dir="build",
    ),
    "python_requires": PYTHON,
}

setup(**config)

