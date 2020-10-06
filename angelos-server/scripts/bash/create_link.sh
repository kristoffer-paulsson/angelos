#!/bin/bash
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

# Creates symlink to Angelos binary.
[ $(id -u) -ne 0 ] && echo "Run as sudo" && exit 1
[ -z "${DESTDIR}" ] && echo "DESTDIR is not set!" && exit 1
[ -z "${ROOT_DIR}" ] && echo "ROOT_DIR is not set!" && exit 1

##########  CREATE_LINK  ##########
ln -sf "$ROOT_DIR/bin/$PACKAGE" "$DESTDIR/usr/local/bin/$PACKAGE"
##########  CREATE_LINK_END  ##########