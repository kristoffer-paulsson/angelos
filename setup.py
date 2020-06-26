#!/usr/bin/env python
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Angelos build script."""
import os
import re
from glob import glob
from os import path
from setuptools import setup, Extension
from Cython.Build import cythonize

base_dir = path.abspath(path.dirname(__file__))


class LibraryScanner:
    """Scan directories for Cython *.pyx files and configure extensions to build."""

    def __init__(self, base_path: str, globlist: list = None, pkgdata: dict = None, data: dict = None):
        self.__base_path = base_path
        self.__globlist = globlist if globlist else ["**.pyx"]
        self.__pkgdata = pkgdata if pkgdata else {}
        self.__data = data if data else {
            "compiler_directives": {
                "language_level": 3,
                "embedsignature": True
            }
        }

    def scan(self) -> list:
        """Build list of Extensions to be cythonized."""
        glob_result = list()
        for pattern in self.__globlist:
            glob_path = os.path.join(self.__base_path, pattern)
            glob_result += glob(glob_path, recursive=True)

        extensions = list()
        for module in glob_result:
            package = re.sub("/", ".", module[len(self.__base_path)+1:-4])
            data = self.__pkgdata[package] if package in self.__pkgdata else {}
            core = {"name": package, "sources": [module]}
            kwargs = {**self.__data, **data, **core}
            extensions.append(Extension(**kwargs))

        return extensions


with open(path.join(base_dir, "README.md")) as desc:
    long_description = desc.read()

with open(path.join(base_dir, "version.py")) as version:
    exec(version.read())

globlist = [
    "libangelos/**.pyx",
    "libangelos/**/*.pyx",
    "angelos/**.pyx",
    "angelos/**/*.pyx"
]

pkgdata = {
    "libangelos.library.nacl": {
        "extra_objects": ["usr/local/lib/libsodium.a"]
    }
}

coredata = {
    "build_dir": "build",
    "cython_c_in_temp": True,
    "compiler_directives": {
        "language_level": 3,
        "embedsignature": True
    }
}


setup(
    name="angelos",
    version=__version__,  # noqa F821
    license="MIT",
    description="A safe messaging system",
    author=__author__,  # noqa F821
    author_email=__author_email__,  # noqa F821
    long_description=long_description,  # noqa F821
    long_description_content_type="text/markdown",
    url=__url__,  # noqa F821
    # project_urls={
    #    "Bug Tracker": "https://bugs.example.com/HelloWorld/",
    #    "Documentation": "https://docs.example.com/HelloWorld/",
    #    "Source Code": "https://code.example.com/HelloWorld/",
    # }
    classifiers=[
        "Development Status :: 2 - Pre-Alpha",
        "Environment :: Console",
        "Environment :: Handhelds/PDA\'s",
        # "Environment :: MacOS X",
        # "Environment :: Win32 (MS Windows)",
        "Environment :: No Input/Output (Daemon)",
        # "Environment :: X11 Applications :: Gnome",
        "Framework :: AsyncIO",
        "Intended Audience :: Developers",
        # "Intended Audience :: End Users/Desktop",
        "Intended Audience :: Information Technology",
        "Intended Audience :: Religion",
        "Intended Audience :: System Administrators",
        "Intended Audience :: Telecommunications Industry",
        "License :: OSI Approved :: MIT License",
        "Operating System :: MacOS :: MacOS X",
        "Operating System :: Microsoft :: Windows",
        "Operating System :: POSIX",
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
    zip_safe=False,
    test_suite="tests",
    python_requires="~=3.7",
    setup_requires=[
        "cython", "pyinstaller", "sphinx", "sphinx_rtd_theme",
        "plyer", "asyncssh", "keyring", "msgpack"],
    install_requires=[],
    # namespace_packages=["angelos", "eidon"],
    packages=["libangelos", "angelos", "eidon", "angelossim"],
    package_dir={"": "lib"},
    scripts=glob("bin/*"),
    ext_modules=cythonize(LibraryScanner("lib", globlist, pkgdata, coredata).scan())
)




