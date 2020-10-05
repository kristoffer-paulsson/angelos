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

# Disable and uninstall service for Angelos.
[ $(id -u) -ne 0 ] && echo "Run as sudo" && exit 1
[ -z "${PACKAGE}" ] && echo "PACKAGE is not set!" && exit 1
[ -z "${DESTDIR}" ] && echo "DESTDIR is not set!" && exit 1

##########  UNINSTALL_SERVICE  ##########
SERVICE_DIR=$DESTDIR/usr/lib/systemd/system

systemctl stop "$PACKAGE.service"
systemctl disable "$PACKAGE.service"
systemctl daemon-reload
rm "$SERVICE_DIR/$PACKAGE.service"
##########  UNINSTALL_SERVICE_END  ##########