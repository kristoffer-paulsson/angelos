# cython: language_level=3, linetrace=True
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
"""Vendor installer, downloads, compiles and install libraries from source."""
import logging
import os
import platform
import shutil
import subprocess
import tarfile
import urllib
import zipfile
from pathlib import Path
from tempfile import TemporaryDirectory
from abc import ABC, abstractmethod
from setuptools import Command


class VendorLibrary(ABC):
    """Base class for vendors."""

    @abstractmethod
    def check(self) -> bool:
        """Check if target is satisfied."""
        pass

    @abstractmethod
    def download(self):
        """Download source tarball."""
        pass

    @abstractmethod
    def extract(self):
        """Extract source file."""
        pass

    def uncompress(self, archive, target):
        """Uncompress Zip or Tar files."""
        if zipfile.is_zipfile(archive):
            zar = zipfile.ZipFile(archive)
            zar.extractall(target)
        elif tarfile.is_tarfile(archive):
            tar = tarfile.open(archive)
            tar.extractall(target)
            tar.close()
        else:
            raise OSError("Unkown zip/archive format")

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


class VendorCompile(VendorLibrary):

    def __init__(
            self, base_dir: str, name: str, download: str,
            local: str, internal: str, check: str, prefix: str = None
    ):
        """

        Example:
            name = "libsodium"
            download = "https://download.libsodium.org/libsodium/releases/libsodium-1.0.18-stable.tar.gz"
            local = "libsodium-1.0.18.tar.gz"
            internal = "libsodium-stable"
            target = "./usr/local/lib/libsodium.a"
        """
        self._base = base_dir
        self._prefix = str(Path(prefix).resolve()) if isinstance(prefix, str) else ""
        self._name = name
        self._download = download
        self._local = local
        self._internal = internal
        self._check = check

        self._tarball = Path(self._base, "tarball", self._local)

        self._temp = TemporaryDirectory()
        self._archive = str(Path(self._temp.name, self._local))
        self._target = str(Path(self._temp.name, self._name))
        self._work = str(Path(self._temp.name, self._name, self._internal))

    def check(self) -> bool:
        """Check if target is reached"""
        return Path(self._base, self._check).exists()

    def download(self):
        """Download sources tarball."""
        if not self._tarball.exists():
            urllib.request.urlretrieve(self._download, self._archive)
            shutil.copyfile(self._archive, str(self._tarball))
        else:
            shutil.copyfile(str(self._tarball), self._archive)

    def extract(self):
        """Extract source file."""
        self.uncompress(self._archive, self._target)

    def close(self):
        """Clean up temporary files."""
        self._temp.cleanup()


class VendorDownload(VendorLibrary):
    """Vendor installer for third party libraries i source code form."""

    def __init__(
            self, base_dir: str, name: str, download: str,
            local: str, internal: str, check: str, prefix: str = None
    ):
        """

        Example:
            name = "libsodium"
            download = "https://download.libsodium.org/libsodium/releases/libsodium-1.0.18-stable.tar.gz"
            local = "libsodium-1.0.18.tar.gz"
            internal = "libsodium-stable"
            target = "./usr/local/lib/libsodium.a"
        """
        self._base = base_dir
        self._prefix = str(Path(prefix).resolve()) if isinstance(prefix, str) else ""
        self._name = name
        self._download = download
        self._local = local
        self._internal = internal
        self._check = check

        self._tarball = Path(self._base, "tarball", self._local)
        self._target = str(Path(self._base, "tarball", self._name))

    def check(self) -> bool:
        """Check if target is reached"""
        return Path(self._base, self._check).exists()

    def download(self):
        """Download sources tarball."""
        if not self._tarball.exists():
            urllib.request.urlretrieve(self._download, self._tarball)

    def extract(self):
        """Extract source file."""
        self.uncompress(str(self._tarball), self._target)

    def build(self):
        pass

    def install(self):
        pass

    def close(self):
        pass


class VendorCompileNacl(VendorCompile):
    """Compile libsodium."""

    def build(self):
        """Build sources."""
        subprocess.check_call("./configure", cwd=self._work, shell=True)
        # CFLAGS='-fPIC -O' CentOS specific only (?)
        if platform.system() == "Linux":
            subprocess.check_call("make CFLAGS='-fPIC -O' && make check", cwd=self._work, shell=True)
        else:
            subprocess.check_call("make && make check", cwd=self._work, shell=True)

    def install(self):
        """Install binaries."""
        subprocess.check_call(
            "make install DESTDIR=$(cd {0}; pwd)".format(Path(self._base)), cwd=self._work, shell=True)


class VendorCompilePython(VendorCompile):
    """Compile and install Python binary."""

    EXCLUDE = (
        "PYCHARM_MATPLOTLIB_INTERACTIVE", "IPYTHONENABLE", "PYDEVD_LOAD_VALUES_ASYNC",
        "__PYVENV_LAUNCHER__", "PYTHONUNBUFFERED", "PYTHONIOENCODING",
        "VERSIONER_PYTHON_VERSION", "PYCHARM_MATPLOTLIB_INDEX", "PYCHARM_DISPLAY_PORT",
        "PYTHONPATH"
    )

    _env = None

    def build(self):
        """Build sources."""
        self._env = {k: os.environ[k] for k in os.environ.keys() if k not in self.EXCLUDE}

        subprocess.run(
            "./configure --enable-optimization --with-lto --prefix={}".format(self._prefix),
            cwd=self._work, shell=True, env=self._env
        )

        subprocess.run("make", cwd=self._work, shell=True, env=self._env)
        # subprocess.run("make test", cwd=self._work, shell=True, env=self._env)

    def install(self):
        """Install binaries."""
        subprocess.run(
            "make install".format(self._prefix), cwd=self._work, shell=True, env=self._env)


class Vendor(Command):
    """Install third party vendor libraries."""

    user_options = [
        ("base-dir=", "d", "Base directory."),
        ("compile=", "c", "Download, compile and install source tarball."),
        ("prefix=", "p", "Possible prefix where to install")
    ]

    def initialize_options(self):
        """Initialize options"""
        self.base_dir = None
        self.compile = None
        self.prefix = None

    def finalize_options(self):
        """Finalize options"""
        pass

    def do_compile(self):
        """Execute the compile command."""
        if not self.compile:
            return

        for value in self.compile:
            logging.info(self.base_dir)
            klass = value["class"]
            del value["class"]
            library = klass(self.base_dir, **value, prefix=self.prefix)
            if not library.check():
                library.download()
                library.extract()
                library.build()
                library.install()
                library.close()

    def run(self):
        """Install vendors."""
        self.do_compile()
