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

# Set permissions for Angelos install.
[ $(id -u) -ne 0 ] && echo "Run as sudo" && exit 1
[ -z "${USERNAME}" ] && echo "USERNAME is not set!" && exit 1
[ -z "${GROUP}" ] && echo "GROUP is not set!" && exit 1
[ -z "${ROOT_DIR}" ] && echo "ROOT_DIR is not set!" && exit 1
[ -z "${CONF_DIR}" ] && echo "CONF_DIR is not set!" && exit 1
[ -z "${VAR_DIR}" ] && echo "VAR_DIR is not set!" && exit 1
[ -z "${LOG_DIR}" ] && echo "LOG_DIR is not set!" && exit 1

# Set ownership and permission in the root directory
##########  PERMISSIONS_ROOT  ##########
find "$ROOT_DIR" -type d -exec chown "$USERNAME":"$GROUP" {} \; -exec chmod 544 {} \;
find "$ROOT_DIR" -type f -exec chown "$USERNAME":"$GROUP" {} \; -exec chmod 400 {} \;
find "$ROOT_DIR" -type f -name "*.so" -or -name "*.dylib" -or -name "*.dll" -exec chown "$USERNAME":"$GROUP" {} \; -exec chmod 500 {} \;
find "$ROOT_DIR/bin" -type f -exec chown "$USERNAME":"$GROUP" {} \; -exec chmod 500 {} \;
##########  PERMISSIONS_ROOT_END  ##########

# Set ownership and permissions in other folders
##########  PERMISSIONS_VAR  ##########
[ ! -d "$VAR_DIR" ] && echo "$VAR_DIR does not exist!" && exit 1
chown "$USERNAME":"$GROUP" "$VAR_DIR"; chmod 700 "$VAR_DIR";
find "$VAR_DIR" -type f -exec chown "$USERNAME":"$GROUP" {} \; -exec chmod 600 {} \;
##########  PERMISSIONS_VAR_END  ##########

##########  PERMISSIONS_LOG  ##########
[ ! -d "$LOG_DIR" ] && echo "$LOG_DIR does not exist!" && exit 1
chown "$USERNAME":"$GROUP" "$LOG_DIR"; chmod 700 "$LOG_DIR";
find "$LOG_DIR" -type f -exec chown "$USERNAME":"$GROUP" {} \; -exec chmod 600 {} \;
##########  PERMISSIONS_LOG_END  ##########

##########  PERMISSIONS_CONF  ##########
[ ! -d "$CONF_DIR" ] && echo "$CONF_DIR does not exist!" && exit 1
chmod 755 "$CONF_DIR";
find "$CONF_DIR" -type f -exec chmod 644 {} \;
##########  PERMISSIONS_CONF_END  ##########