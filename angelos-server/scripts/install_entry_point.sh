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

DATA_ENV_JSON=$(cat <<EOF
{}
EOF
)

DATA_CONFIG_JSON=$(cat <<EOF
{}
EOF
)

DATA_SYSTEMD_SERVICE=$(cat <<EOF
[Unit]
Description = Run the Angelos server
After = network.target

[Service]
Type = forking
AmbientCapabilities = CAP_NET_BIND_SERVICE

ExecStart = $NAME_NIX -d start
ExecStop = $NAME_NIX -d stop
ExecReload = $NAME_NIX -d restart

User = $USERNAME
Group = $GROUPNAME

# RootDirectory = $DIR_ANGELOS
RuntimeDirectory = $NAME_NIX
StateDirectory = $DIR_VAR
LogsDirectory = $DIR_LOG
ConfigurationDirectory = $DIR_ETC

KeyringMode = private

[Install]
WantedBy=default.target
EOF
)

# Check sudo access
if [ $(id -u) -ne 0 ]
  then echo "Run as sudo"
  exit
fi

# Create user and group for angelos
grep $GROUPNAME /etc/group 2>&1>/dev/null
if [ $? != 0 ]
then
  groupadd $GROUPNAME
else
  printf "Group $GROUPNAME already exists.\n"
fi

if id $USERNAME >/dev/null 2>&1; then
  printf "User $USERNAME already exists.\n"
else
  useradd $USERNAME --system -g $GROUPNAME
fi

# Create directories for angelos
mkdir $DIR_VAR -p
mkdir $DIR_LOG -p
mkdir $DIR_ETC -p

# Create admin public keys file
if [ -s "$FILE_ADMINS" ]
then
   echo "$FILE_ADMINS already exists, left untouched."
else
  echo "" > $FILE_ADMINS
fi

# Create configuration
if [ -s "$FILE_ENV" ]
then
   echo "$FILE_ENV already exists, left untouched."
else
  echo $DATA_ENV_JSON > $FILE_ENV
fi

if [ -s "$FILE_CONF" ]
then
   echo "$FILE_CONF already exists, left untouched."
else
  echo $DATA_CONFIG_JSON > $FILE_CONF
fi

# Setup systemd service
if [ -s "$FILE_SERVICE" ]
then
   echo "$FILE_SERVICE already exists, left untouched."
else
  echo "" > /usr/lib/systemd/system/angelos.service
  chmod 644 $FILE_SERVICE
  systemctl daemon-reload
  systemctl enable
  echo "Run '>sudo systemctl start $NAME_SERVICE' in order to start angelos."
fi

# Set angelos:angelos ownership
chown -R $USERNAME:$GROUPNAME $DIR_ANGELOS
chown -R $USERNAME:$GROUPNAME $DIR_VAR
chown -R $USERNAME:$GROUPNAME $DIR_LOG
chown -R $USERNAME:$GROUPNAME $DIR_ETC

# Make angelos binary accessible
ln -sf $FILE_EXE $LINK_EXE