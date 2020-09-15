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

NAME_NIX=angelos
NAME_SERVICE=$NAME_NIX.service

USERNAME=$NAME_NIX
GROUPNAME=$NAME_NIX

DIR_ANGELOS=/opt/$NAME_NIX
DIR_VAR=/var/lib/$NAME_NIX
DIR_LOG=/var/log/$NAME_NIX
DIR_ETC=/etc/$NAME_NIX

LINK_EXE=/usr/local/bin/$NAME_NIX

FILE_EXE=$DIR_ANGELOS/bin/$NAME_NIX
FILE_ADMINS=$DIR_VAR/admins.pub
FILE_ENV=$DIR_ETC/env.json
FILE_CONF=$DIR_ETC/config.json
FILE_SERVICE=/etc/systemd/system/$NAME_SERVICE

# Check sudo access
if [ $(id -u) -ne 0 ]
  then echo "Run as sudo"
  exit
fi

# Remove systemd entry
systemctl stop $NAME_SERVICE
systemctl disable $NAME_SERVICE
rm $FILE_SERVICE
systemctl daemon-reload

# Remove angelos link
rm $LINK_EXE

# Remove all angelos files
# rm -fR /var/lib/angelos/*
# rm -fR /var/log/angelos/*
rm -fR $DIR_ETC/*
rm -fR $DIR_ANGELOS/*

# Remove all angelos directories
# rmdir /var/lib/angelos
# rmdir /var/log/angelos
rmdir $DIR_ETC
rmdir $DIR_ANGELOS