# cython: language_level=3
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
"""Multiplatform key loader mechanism."""
import base64
import sys
import os
from abc import ABC, abstractmethod

from angelos.bin.nacl import SecretBox


class KeyLoadError(RuntimeWarning):
    """Any problem with loading, storing and deleting keys."""


class BaseKeyLoader(ABC):
    """Key loader base class. Subclass this for different backends."""

    SYSTEM = "Unknown"

    @classmethod
    @abstractmethod
    def _get_key(cls, realm: str, name: str) -> bytes:
        pass

    @classmethod
    @abstractmethod
    def _set_key(cls, realm: str, name: str, key: bytes):
        pass

    @classmethod
    @abstractmethod
    def _del_key(cls, realm: str, name: str) -> bytes:
        pass

    @classmethod
    def new(cls) -> bytes:
        """Generate a new secret."""
        return SecretBox().sk

    @classmethod
    def get(cls) -> bytes:
        """Get the key."""
        key = base64.b64decode(cls._get_key(cls.SYSTEM, "angelos-conceal"))
        box = SecretBox(key)
        master = base64.b64decode(cls._get_key(cls.SYSTEM, "angelos-masterkey"))
        master_key = box.decrypt(master)
        return master_key

    @classmethod
    def set(cls, master: bytes, key: bytes = None):
        """Save a key, generate new if none given."""
        if key is None:
            key = cls.new()

        cls._set_key(cls.SYSTEM, "angelos-conceal", base64.b64encode(key))
        box = SecretBox(key)

        cls._set_key(
            cls.SYSTEM, "angelos-masterkey", base64.b64encode(
                box.encrypt(master)))

    @classmethod
    def redo(cls):
        """"""
        cls.set(cls.get())


if sys.platform.startswith("darwin"):

    import getpass
    from subprocess import Popen, PIPE


    class KeyLoader(BaseKeyLoader):
        """Keyloader for the keychain in Darwin/macOS."""

        @classmethod
        def _get_key(cls, realm: str, name: str) -> bytes:
            with Popen("security find-generic-password -w -a{a} -s{s}".format(
                    a=getpass.getuser(), s=name), shell=True, stdout=PIPE) as proc:
                if proc.returncode:
                    raise KeyLoadError(
                        "Get key '{}' failed: {}".format(name, proc.returncode))
                else:
                    return proc.stdout.read()

        @classmethod
        def _set_key(cls, realm: str, name: str, key: bytes):
            with Popen("security add-generic-password -a{a} -s{s} -w{w}".format(
                    a=getpass.getuser(), s=name, w=key), shell=True) as proc:
                if proc.returncode:
                    raise KeyLoadError(
                        "Set key '{}' failed: {}".format(name, proc.returncode))

        @classmethod
        def _del_key(cls, realm: str, name: str) -> bytes:
            with Popen("security delete-generic-password -a{a} -s{s}".format(
                    a=getpass.getuser(), s=name), shell=True) as proc:
                if proc.returncode:
                    raise KeyLoadError(
                        "Delete key '{}' failed: {}".format(name, proc.returncode))

elif sys.platform.startswith("win32"):

    import getpass
    import win32cred


    class KeyLoader(BaseKeyLoader):
        """Keyloader for the keychain in Windows."""

        COMPOUND = "{username}@{service}"

        @classmethod
        def _get_key(cls, realm: str, name: str) -> bytes:
            data = win32cred.CredRead(
                Type=win32cred.CRED_TYPE_GENERIC,
                TargetName=cls.COMPOUND.format(username=getpass.getuser(), service=name)
            )
            if not data:
                raise KeyLoadError(
                    "Get key '{}' failed: {}".format(name, ""))
            else:
                return data["CredentialBlob"].decode('utf-16').encode()

        @classmethod
        def _set_key(cls, realm: str, name: str, key: bytes):
            username = getpass.getuser()
            win32cred.CredWrite({
                "Type": win32cred.CRED_TYPE_GENERIC,
                "TargetName": cls.COMPOUND.format(username=username, service=name),
                "UserName": username,
                "CredentialBlob": key.decode(),
                "Comment": "",
                "Persist": win32cred.CRED_PERSIST_ENTERPRISE
            }, 0)

        @classmethod
        def _del_key(cls, realm: str, name: str):
            win32cred.CredDelete(
                Type=win32cred.CRED_TYPE_GENERIC,
                TargetName=cls.COMPOUND.format(username=getpass.getuser(), service=name)
            )

elif "gnome" in os.environ.get("GDMSESSION", ""):

    from subprocess import Popen, PIPE


    class KeyLoader(BaseKeyLoader):
        """Keyloader for the keychain in Linux/GNOME."""

        @classmethod
        def _get_key(cls, realm: str, name: str) -> bytes:
            with Popen("secret-tool lookup password \"{n}\"".format(n=name), shell=True, stdout=PIPE) as proc:
                if proc.returncode:
                    raise KeyLoadError(
                        "Get key '{}' failed: {}".format(name, proc.returncode))
                else:
                    return proc.stdout.read()

        @classmethod
        def _set_key(cls, realm: str, name: str, key: bytes):
            with Popen("secret-tool store --label=\"{r} {n}\" password \"{n}\"".format(
                    r=cls.SYSTEM, n=name), shell=True, stdout=PIPE, stdin=PIPE) as proc:
                # proc.stdin.write(key)
                proc.communicate(key, 2)
                if proc.returncode:
                    raise KeyLoadError(
                        "Set key '{}' failed: {}".format(name, proc.returncode))

        @classmethod
        def _del_key(cls, realm: str, name: str) -> bytes:
            with Popen("secret-tool clear password \"{n}\"".format(n=name), shell=True) as proc:
                if proc.returncode:
                    raise KeyLoadError(
                        "Delete key '{}' failed: {}".format(name, proc.returncode))

else:

    class KeyLoader(BaseKeyLoader):
        """Dummy implementation."""

        @classmethod
        def _get_key(cls, realm: str, name: str):
            raise NotImplementedError("Not implemented for platform: {}".format(sys.platform))

        @classmethod
        def _set_key(cls, realm: str, name: str, key: bytes):
            raise NotImplementedError("Not implemented for platform: {}".format(sys.platform))

        @classmethod
        def _del_key(cls, realm: str, name: str):
            raise NotImplementedError("Not implemented for platform: {}".format(sys.platform))
