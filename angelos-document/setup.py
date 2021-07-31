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
from angelos.meta.setup import LibraryScanner
from setuptools import setup, find_namespace_packages

NAME = "angelos.document"
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
        str(Path("angelos/document/*.pyx"))
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
          "Development Status :: 5 - Production/Stable",
          "Intended Audience :: Developers",
          "License :: OSI Approved :: MIT License",
          "Programming Language :: Cython",
          "Topic :: Software Development :: Libraries",
    ],
    "install_requires": ["msgpack"],
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
    "python_requires": PYTHON,
}

setup(**config)