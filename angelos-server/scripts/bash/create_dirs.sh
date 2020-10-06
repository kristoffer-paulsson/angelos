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

# Creates directories for Angelos install.
[ $(id -u) -ne 0 ] && echo "Run as sudo" && exit 1
[ -z "${CONF_DIR}" ] && echo "CONF_DIR is not set!" && exit 1
[ -z "${VAR_DIR}" ] && echo "VAR_DIR is not set!" && exit 1
[ -z "${LOG_DIR}" ] && echo "LOG_DIR is not set!" && exit 1

##########  CREATE_DIRS  ##########
install -d -m 0755 "$CONF_DIR"
install -d -g $GROUP -o $USERNAME -m 0700 "$VAR_DIR"
install -d -g $GROUP -o $USERNAME -m 0700 "$LOG_DIR"
##########  CREATE_DIRS_END  ##########