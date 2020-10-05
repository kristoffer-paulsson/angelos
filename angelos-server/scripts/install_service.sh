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

# Install and enable service for Angelos.
[ $(id -u) -ne 0 ] && echo "Run as sudo" && exit 1
[ -z "${USERNAME}" ] && echo "USERNAME is not set!" && exit 1
[ -z "${GROUP}" ] && echo "GROUP is not set!" && exit 1
[ -z "${PACKAGE}" ] && echo "PACKAGE is not set!" && exit 1
[ -z "${DESTDIR}" ] && echo "DESTDIR is not set!" && exit 1

##########  INSTALL_SERVICE  ##########
SERVICE_DIR=$DESTDIR/usr/lib/systemd/system

SERVICE=<<EOF
[Unit]
Description = Run the Angelos server
After = network.target

[Service]
Type = forking
AmbientCapabilities = CAP_NET_BIND_SERVICE

ExecStart = $PACKAGE -d start
ExecStop = $PACKAGE -d stop
ExecReload = $PACKAGE -d restart

User = $USERNAME
Group = $GROUP

RuntimeDirectory = $PACKAGE
StateDirectory = $PACKAGE
LogsDirectory = $PACKAGE
ConfigurationDirectory = $PACKAGE

KeyringMode = private

[Install]
WantedBy=default.target
EOF

install -D -m 0644 <"$SERVICE" "$SERVICE_DIR/$PACKAGE.service"
systemctl enable "$PACKAGE.service"
systemctl daemon-reload
##########  INSTALL_SERVICE_END  ##########