# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import base64

import libnacl
import plyer

from .policy import Policy


class KeyLoader(Policy):
    @staticmethod
    def new():
        return libnacl.secret.SecretBox().sk

    @staticmethod
    def set(master, key=None):
        if key is None:
            key = KeyLoader.new()

        plyer.keystore.set_key(
            'Λόγῳ', 'conceal', base64.b64encode(key).decode())
        box = libnacl.secret.SecretBox(key)
        plyer.keystore.set_key(
            'Λόγῳ', 'masterkey', base64.b64encode(
                box.encrypt(master)).decode())

    @staticmethod
    def get():
        key = base64.b64decode(plyer.keystore.get_key('Λόγῳ', 'conceal'))
        box = libnacl.secret.SecretBox(key)
        master = base64.b64decode(plyer.keystore.get_key('Λόγῳ', 'masterkey'))
        return box.decrypt(master)

    @staticmethod
    def redo():
        KeyLoader.set(KeyLoader.get())
