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

#Variables for the Angelos installation scripts.
[ $(id -u) -ne 0 ] && echo "Run as sudo" && exit 1
[ -z "${DESTDIR}" ] && echo "DESTDIR is not set!" && exit 1

##########  VARIABLES  ##########
PACKAGE=angelos

USERNAME=$PACKAGE
GROUP=$PACKAGE

ROOT_DIR=$DESTDIR/opt/$PACKAGE
VAR_DIR=$DESTDIR/var/lib/$PACKAGE
LOG_DIR=$DESTDIR/var/log/$PACKAGE
CONF_DIR=$DESTDIR/etc/$PACKAGE
##########  VARIABLES_END  ##########

export PACKAGE
export USERNAME
export GROUP
export ROOT_DIR
export VAR_DIR
export LOG_DIR
export CONF_DIR