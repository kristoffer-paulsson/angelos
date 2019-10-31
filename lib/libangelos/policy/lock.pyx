# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module string"""
import sys
import base64
import logging

import libnacl

from .policy import Policy

if sys.platform.startswith('darwin'):
    import macos_keychain

    def get_key(realm, name):
        try:
            result = macos_keychain.get(name=name)
        except Exception as e:
            logging.error(e, exc_info=True)
            result = None

        return result

    def set_key(realm, name, key):
        try:
            macos_keychain.add(name=name, value=key)
        except Exception as e:
            logging.error(e, exc_info=True)
else:
    import plyer

    def get_key(realm, name):
        return plyer.keystore.get_key(realm, name)

    def set_key(realm, name, key):
        plyer.keystore.set_key(realm, name, key)


class KeyLoader(Policy):
    @staticmethod
    def new():
        return libnacl.secret.SecretBox().sk

    @staticmethod
    def set(master, key=None):
        if key is None:
            key = KeyLoader.new()

        set_key("Λόγῳ", "angelos-conceal", base64.b64encode(key).decode())
        box = libnacl.secret.SecretBox(key)

        set_key(
            "Λόγῳ", "angelos-masterkey", base64.b64encode(
                box.encrypt(master)).decode())

    @staticmethod
    def get():
        key = base64.b64decode(get_key("Λόγῳ", "angelos-conceal"))
        box = libnacl.secret.SecretBox(key)
        master = base64.b64decode(get_key("Λόγῳ", "angelos-masterkey"))
        master_key = box.decrypt(master)
        return master_key

    @staticmethod
    def redo():
        KeyLoader.set(KeyLoader.get())
