#!/usr/bin/env python
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

"""Angelos build script."""
import os
import re
import sys
import tarfile
import tempfile
import subprocess

import urllib
from abc import ABC, abstractmethod
from glob import glob
from os import path
from pathlib import Path

from setuptools import setup, Extension, Command as _Command
from setuptools.command.install import install as setup_install
from Cython.Build import cythonize
from Cython.Compiler import Options


base_dir = str(Path(__file__).parent.absolute())
Options.docstrings = False
major, minor, _, _, _ = sys.version_info
PY_VER = "{0}.{1}".format(major, minor)


class Command(_Command):
    user_options = [
    ]

    def initialize_options(self):
        """Initialize options"""
        pass

    def finalize_options(self):
        """Finalize options"""
        pass


class BuildSetup(Command):
    """Preparations and adaptions of building the app."""

    def run(self):
        """Carry out preparations and adaptions."""
        self.run_command("executable")

        if sys.platform == "darwin":
            pass

        if sys.platform == "darwin":
            self.run_command("pkg_rpm")


class PackageRpm(Command):
    """Build a macos dmg image."""

    def run(self):
        pass


class Executable(Command):
    """Compile the executable"""

    def run(self):
        name = "angelos"
        self._dist = str(Path("./bin").absolute())
        self._temp = tempfile.TemporaryDirectory()

        temp_name = str(Path(self._temp.name, name).absolute())
        home = str(Path("./").absolute())

        cflags = subprocess.check_output(
            "python{}-config --cflags".format(PY_VER), stderr=subprocess.STDOUT, shell=True).decode()
        ldflags = subprocess.check_output(
            "python{}-config --ldflags".format(PY_VER), stderr=subprocess.STDOUT, shell=True).decode()

        subprocess.check_call(
            "cython --embed -3 -o {}.c ./scripts/{}_entry_point.pyx".format(
                temp_name, name), cwd=home, shell=True)

        subprocess.check_call(
            "gcc -o {0}.o -c {0}.c {1}".format(
                temp_name, cflags), cwd=self._temp.name, shell=True)

        subprocess.check_call(
            "gcc -o ./{0} {1}.o {2}".format(
                name, temp_name, ldflags), cwd=home, shell=True)

        self._temp.cleanup()


class TestRunner(setup_install):
    """Install third party vendor libraries."""

    def run(self):
        """Install vendors."""
        subprocess.check_call("python ./tests/test_certified.py", shell=True)


class VendorLibrary(ABC):
    """Base class for downloading and installing a third party library."""

    NAME = "vendor_name"
    DOWNLOAD = "https://download.url/whatever.tar.gz"
    LOCALFILE = "library_name.tar.gz"
    INTERNAL = "library-root"

    @abstractmethod
    def check(self) -> bool:
        """Check if already exists."""
        pass

    @abstractmethod
    def download(self):
        """Download source tarball."""
        pass

    @abstractmethod
    def extract(self):
        """Extract source file."""
        pass

    @abstractmethod
    def build(self):
        """Build sources."""
        pass

    @abstractmethod
    def install(self):
        """Install binaries."""
        pass

    @abstractmethod
    def close(self):
        """Clean up temporary files."""
        pass


class VendorLibsodium(VendorLibrary):
    """Libsodium installer."""

    NAME = "libsodium"
    DOWNLOAD = "https://download.libsodium.org/libsodium/releases/libsodium-1.0.18-stable.tar.gz"
    LOCALFILE = "libsodium.tar.gz"
    INTERNAL = "libsodium-stable"

    def __init__(self, base_dir: str):
        self._base = base_dir
        self._temp = tempfile.TemporaryDirectory()
        self._archive = os.path.join(self._temp.name, self.LOCALFILE)
        self._target = os.path.join(self._temp.name, self.NAME)
        self._work = os.path.join(self._temp.name, self.NAME, self.INTERNAL)

    def check(self) -> bool:
        """Check if already exists."""
        return os.path.isfile(os.path.join(self._base, "usr", "local", "lib", "libsodium.a"))

    def download(self):
        """Download sources tarball."""
        urllib.request.urlretrieve(self.DOWNLOAD, self._archive)

    def extract(self):
        """Extract source file."""
        tar = tarfile.open(self._archive)
        tar.extractall(self._target)
        tar.close()

    def build(self):
        """Build sources."""
        subprocess.check_call("./configure", cwd=self._work, shell=True)
        # CFLAGS='-fPIC -O' CentOS specific only (?)
        subprocess.check_call("make CFLAGS='-fPIC -O' && make check", cwd=self._work, shell=True)

    def install(self):
        """Install binaries."""
        subprocess.check_call("make install DESTDIR=$(cd {}; pwd)".format(self._base), cwd=self._work, shell=True)

    def close(self):
        """Clean up temporary files."""
        self._temp.cleanup()


class VendorInstall(setup_install):
    """Install third party vendor libraries."""

    LIBRARIES = (VendorLibsodium,)

    def run(self):
        """Install vendors."""
        for vendor_library in self.LIBRARIES:
            library = vendor_library(base_dir)
            if not library.check():
                library.download()
                library.extract()
                library.build()
                library.install()
                library.close()

        setup_install.run(self)


class LibraryScanner:
    """Scan directories for Cython *.pyx files and configure extensions to build."""

    def __init__(self, base_path: str, glob: list = None, extra: dict = None, basic: dict = None):
        self.__base_path = base_path
        self.__globlist = glob if glob else ["**.pyx"]
        self.__pkgdata = extra if extra else {}
        self.__data = basic if basic else {
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
            package = re.sub("/", ".", module[len(self.__base_path) + 1:-4])
            data = self.__pkgdata[package] if package in self.__pkgdata else {}
            core = {"name": package, "sources": [module]}
            kwargs = {**self.__data, **data, **core}
            extensions.append(Extension(**kwargs))

        return extensions


class LibraryBuilder(Command):
    """Build standalone library with includes."""

    def run(self):
        """Build list of Extensions to be cythonized."""
        name = "libangelos"
        base_path = os.path.abspath(os.path.dirname(__file__))
        glob_result = list()
        for pattern in [name + "/**.pyx", name + "/**/*.pyx"]:
            glob_path = os.path.join(".", "lib", pattern)
            glob_result += glob(glob_path, recursive=True)

        content = "# cython: language_level=3\n"
        for src_file in glob_result:
            content += "include \"{}\"\n".format(src_file[6:])

        with open(os.path.join(base_path, "lib", name + ".pyx"), "xb+") as output:
            output.write(content.encode())


with open(path.join(base_dir, "README.md")) as desc:
    long_description = desc.read()

with open(path.join(base_dir, "version.py")) as version:
    exec(version.read())

lib_scan = {
    "glob": [
        "libangelos/**.pyx",
        "libangelos/**/*.pyx",
        "angelos/**.pyx",
        "angelos/**/*.pyx"
    ],
    "extra": {
        "libangelos.library.nacl": {
            "extra_objects": ["usr/local/lib/libsodium.a"],
            "include_dirs": [os.path.join(base_dir, "usr", "local", "include")]  # CentOS specific only (?)
        }
    },
    "basic": {
    }
}

setup(
    cmdclass={
        "make": BuildSetup,
        "install": VendorInstall,
        "test": TestRunner,
        "pkg_rpm": PackageRpm,
        "executable": Executable
    },
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
    python_requires="~=3.7",
    install_requires=[
        # Build tools requirements
        # "tox", "cython", "sphinx", "sphinx_rtd_theme",
        # Software import requirements
        "plyer", "asyncssh~=2.3", "msgpack",
        # Platform specific requirements
        # [Windows|Linux|Darwin]
    ],
    tests_require=[],
    packages=["libangelos", "angelos", "eidon", "angelossim"],
    package_dir={"": "lib"},
    scripts=glob("bin/*"),
    ext_modules=cythonize(
        LibraryScanner("lib", **lib_scan).scan(),
        build_dir="build",
        compiler_directives={
            "language_level": 3,
        }
    )
)
