#!/usr/bin/env python
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Angelos build script."""
import os
import re
import subprocess
import tarfile
import tempfile

import urllib
from abc import ABC, abstractmethod
from glob import glob
from os import path
from setuptools import setup, Extension
from setuptools.command.install import install as setup_install
from Cython.Build import cythonize

base_dir = path.abspath(path.dirname(__file__))


class VendorLibrary(ABC):
    """Base class for downloading and installing a third party library."""

    NAME = "vendor_name"
    DOWNLOAD = "https://download.url/whatever.tar.gz"
    LOCALFILE = "library_name.tar.gz"
    INTERNAL = "library-root"

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
        subprocess.check_call("make && make check", cwd=self._work, shell=True)

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
            library.download()
            library.extract()
            library.build()
            library.install()
            library.close()

        setup_install.run(self)


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
    cmdclass={"install": VendorInstall},
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
        "cython", "pyinstaller", "sphinx", "sphinx_rtd_theme",
        # Software import requirements
        "plyer", "asyncssh", "keyring", "msgpack",
        # Platform specific requirements
        # [Windows|Linux|Darwin]
        "macos_keychain; platform_system == 'Darwin'",
    ],
    tests_require=[],
    packages=["libangelos", "angelos", "eidon", "angelossim"],
    package_dir={"": "lib"},
    scripts=glob("bin/*"),
    ext_modules=cythonize(LibraryScanner("lib", globlist, pkgdata, coredata).scan())
)




