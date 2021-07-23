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
"""Angelos server entry point to be compiled into an executable."""


if __name__ == '__main__':
    import sys
    import pathlib
    import platform

    major, minor, _, _, _ = sys.version_info
    PY_VER = "{0}.{1}".format(major, minor)
    system = platform.system()

    if system == "Linux":

        site = pathlib.Path("/opt/angelos/angelos/lib/python{}/site-packages".format(PY_VER))
        if site.exists():
            sys.path.insert(0, str(site))

        site64 = pathlib.Path("/opt/angelos/angelos/lib64/python{}/site-packages".format(PY_VER))
        if site64.exists():
            sys.path.insert(0, str(site64))

    else:
        print("Unsupported platform ({})".format(system))
        exit(1)

    try:
        from angelos.server.main import start
    except ModuleNotFoundError:
        print("Could not locate Angelos installation.")
        exit(1)
    else:
        exit(start())
