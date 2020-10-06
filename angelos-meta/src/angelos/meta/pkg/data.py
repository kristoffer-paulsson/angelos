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
"""Data variables when packaging and installing."""
from configparser import ConfigParser
from pathlib import Path

path = Path(*Path(__file__).parts[:-6], "version.ini")

if path.exists():
    config = ConfigParser()
    config.read(str(path))
else:
    config = None

AUTHOR = config["internal"]["author"] if config else None
AUTHOR_EMAIL = config["internal"]["author_email"] if config else None
URL = config["internal"]["url"] if config else None
VERSION = config["internal"]["version"] if config else None

NAME_NIX = "angelos"
LICENSE = "MIT"

NAME_SERVICE = "{}.service".format(NAME_NIX)

USERNAME = "{}".format(NAME_NIX)
GROUPNAME = "{}".format(NAME_NIX)

DIR_ANGELOS = "/opt/{}".format(NAME_NIX)
DIR_VAR = "/var/lib/{}".format(NAME_NIX)
DIR_LOG = "/var/log/{}".format(NAME_NIX)
DIR_ETC = "/etc/{}".format(NAME_NIX)

LINK_EXE = "/usr/local/bin/{}".format(NAME_NIX)

FILE_EXE = "{0}/bin/{1}".format(DIR_ANGELOS, NAME_NIX)
FILE_ADMINS = "{0}/admins.pub".format(DIR_VAR)
FILE_ENV = "{}/env.json".format(DIR_ETC)
FILE_CONF = "{}/config.json".format(DIR_ETC)
FILE_SERVICE = "/etc/systemd/system/{}".format(NAME_SERVICE)

EXEC_PREFIX = "{}/bin".format(DIR_ANGELOS)
EXEC_SUFFIX = ".so"
PERMS_EXEC = 500
PERMS_FILE = 400
PERMS_DIR = 544

FILTER = [
    ".dist-info",
    "/test/",
    "/tests/",
    "/unittest/",
    "/test_",
    "/distutils/",
    "/angelos/meta/",
    "/tkinter/",
    "/turtledemo/",
    "/idlelib/",
    "/ensurepip/",
    "/lib2to3/",
    "/venv/",
    "/sqlite3/",
    "/wsgiref/",
    "/xmlrpc/",
    "/dbm/",
    "/pydoc_data/",
]

DEBIAN = {
    "build_deps": [
        "zlib1g-dev",
        "libncurses5-dev",
        "libgdbm-dev",
        "libnss3-dev",
        "libssl-dev",
        "libreadline-dev",
        "libffi-dev",
        "libbz2-dev",
        "libsqlite3-dev"
    ],
    "run_deps": [
        "zlib1g",
        "libncurses5",
        "libgdbm6",
        "libnss3",
        "libssl1.1",
        "libreadline7",
        "libffi6",
        "bzip2",
        "libsqlite3-0"
    ],
    "pre_inst": [
        "VARIABLES",
        "CREATE_USER"
    ],
    "post_inst": [
        "VARIABLES",
        "CREATE_LINK",
        "PERMISSIONS_ROOT",
        "PERMISSIONS_VAR",
        "PERMISSIONS_LOG",
        "PERMISSIONS_CONF"
    ],
    "pre_rem": [
        "VARIABLES",
        "REMOVE_LINK"
    ],
    "post_rem": [
        "VARIABLES"
    ]
}

CENTOS = {
    "build_deps": [
        "bzip2-devel",
        "expat-devel",
        "gdbm-devel",
        "ncurses-devel",
        "openssl-devel",
        "readline-devel",
        "sqlite-devel",
        "tk-devel",
        "xz-devel",
        "zlib-devel",
        "libffi-devel"
    ],
    "run_deps": [
        "bzip2-libs",
        "expat",
        "gdbm-libs",
        "ncurses-libs",
        "openssl-libs",
        "readline",
        "sqlite-libs",
        "tk",
        "xz-libs",
        "zlib",
        "libffi"
    ],
    "pre_inst": [
        "VARIABLES",
        "CREATE_USER"
    ],
    "post_inst": [
        "VARIABLES",
        "INSTALL_ADMINS",
        "CREATE_LINK"
    ],
    "pre_rem": [
        "VARIABLES",
        "REMOVE_LINK"
    ],
    "post_rem": [
        "VARIABLES"
    ]
}
