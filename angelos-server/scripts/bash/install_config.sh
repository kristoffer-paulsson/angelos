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

# Install configurations files for Angelos install.
[ $(id -u) -ne 0 ] && echo "Run as sudo" && exit 1
[ -z "${USERNAME}" ] && echo "USERNAME is not set!" && exit 1
[ -z "${GROUP}" ] && echo "GROUP is not set!" && exit 1
[ -z "${CONF_DIR}" ] && echo "CONF_DIR is not set!" && exit 1
! [ -d "$CONF_DIR" ] && echo "$CONF_DIR does not exist!" && exit 1

##########  INSTALL_ENV  ##########
ENV=$( cat <<EOF
{}
EOF
)
install -D -m 0644 -g "$GROUP" -o "$USERNAME" <"$ENV" "$CONF_DIR/env.json"
##########  INSTALL_ENV_END  ##########

##########  INSTALL_CONFIG  ##########
CONFIG=$( cat <<EOF
{}
EOF
)

install -D -m 0644 -g "$GROUP" -o "$USERNAME" <"$CONFIG" "$CONF_DIR/config.json"
##########  INSTALL_CONFIG_END  ##########

##########  INSTALL_ADMINS  ##########
install -D -m 0600 -g "$GROUP" -o "$USERNAME" <"" "$VAR_DIR/admins.pub"
##########  INSTALL_ADMINS_END  ##########

