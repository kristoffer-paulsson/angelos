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
"""All constants goes here."""


class Const:
    """
    All global constants.

    Bla bla bla

    Attributes:
    A_TYPE_PERSON_CLIENT    Archive type for PersonClientFacade
    A_TYPE_PERSON_SERVER    Archive type for PersonServerFacade
    A_TYPE_MINISTRY_CLIENT  Archive type for MinistryClientFacade
    A_TYPE_MINISTRY_SERVER  Archive type for MinistryServerFacade
    A_TYPE_CHURCH_CLIENT    Archive type for ChurchClientFacade
    A_TYPE_CHURCH_SERVER    Archive type for ChurchServerFacade

    A_TYPE_ADMIN_CLIENT     Mapping for type AdminClientFacade

    A_TYPE_BEARER           Archive type for courier data.
    A_TYPE_SEED             Archive type for seed data.
    A_TYPE_ARCHIVE          Archive type for general fs data.

    A_ROLE_PRIMARY          Current node has a primary role in the domain
    A_ROLE_BACKUP           Current node has a backup role in the domain

    A_USE_VAULT             Archive used as vault
    A_USE_HOME              Archive used as an encrypted home directory
    A_USE_MAIL              Archive used as intrachurch mail routing pool
    A_USE_POOL              Archive used as public document pool
    A_USE_FTP               Archive used as encrypted ftp file system
    A_USE_ROUTING           Archive used as interchurch mail routing pool
    A_USE_META              Archive used as internal node meta-information

    CNL_VAULT               Vault file path
    CNL_HOME                Encrypted home directory file path
    CNL_MAIL                Mail routing pool file path
    CNL_POOL                Public document pool file path
    CNL_FTP                 Encrypted ftp file path
    CNL_ROUTING             Mail routing pool file path
    CNL_META                Meta information storage path

    """

    A_TYPE_PERSON_CLIENT = ord(b"p")
    A_TYPE_PERSON_SERVER = ord(b"P")
    A_TYPE_MINISTRY_CLIENT = ord(b"m")
    A_TYPE_MINISTRY_SERVER = ord(b"M")
    A_TYPE_CHURCH_CLIENT = ord(b"c")
    A_TYPE_CHURCH_SERVER = ord(b"C")

    A_TYPE_ADMIN_CLIENT = ord(b"A")
    A_TYPE_BOOT_SERVER = ord(b"B")

    A_TYPE_BEARER = ord(b"b")
    A_TYPE_SEED = ord(b"s")
    A_TYPE_ARCHIVE = ord(b"a")

    A_ROLE_PRIMARY = ord(b"p")
    A_ROLE_BACKUP = ord(b"b")

    A_USE_VAULT = ord(b"v")
    A_USE_HOME = ord(b"h")
    A_USE_MAIL = ord(b"m")
    A_USE_POOL = ord(b"p")
    A_USE_FTP = ord(b"f")
    A_USE_ROUTING = ord(b"r")
    A_USE_META = ord(b"M")

    CNL_VAULT = "vault.ar7"
    CNL_HOME = "home.ar7"
    CNL_MAIL = "mail.ar7"
    CNL_POOL = "pool.ar7"
    CNL_FTP = "ftp.ar7"
    CNL_ROUTING = "routing.ar7"
    CNL_META = "meta.ar7"

    OPT_LISTEN = ["localhost", "loopback", "hostname", "domain", "ip", "any"]

    ARCH_BLK_1 = 227
    ARCH_BLK_2 = 454
    ARCH_BLK_4 = 908
