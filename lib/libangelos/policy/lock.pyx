# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module string"""
import base64
import sys

from libangelos.library.nacl import SecretBox
from libangelos.policy.policy import Policy

if sys.platform.startswith('darwin'):
    import macos_keychain

    def get_key(realm, name):
        return macos_keychain.get(name=name)

    def set_key(realm, name, key):
        macos_keychain.add(name=name, value=key)
else:
    import plyer

    def get_key(realm, name):
        return plyer.keystore.get_key(realm, name)

    def set_key(realm, name, key):
        plyer.keystore.set_key(realm, name, key)


class KeyLoader(Policy):
    @staticmethod
    def new():
        return SecretBox().sk

    @staticmethod
    def set(master, key=None):
        if key is None:
            key = KeyLoader.new()

        set_key("Λόγῳ", "angelos-conceal", base64.b64encode(key).decode())
        box = SecretBox(key)

        set_key(
            "Λόγῳ", "angelos-masterkey", base64.b64encode(
                box.encrypt(master)).decode())

    @staticmethod
    def get():
        key = base64.b64decode(get_key("Λόγῳ", "angelos-conceal"))
        box = SecretBox(key)
        master = base64.b64decode(get_key("Λόγῳ", "angelos-masterkey"))
        master_key = box.decrypt(master)
        return master_key

    @staticmethod
    def redo():
        KeyLoader.set(KeyLoader.get())
