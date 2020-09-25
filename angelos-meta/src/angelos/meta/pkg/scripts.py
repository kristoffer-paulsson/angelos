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
"""Instann and uninstall scriptlets."""
from .data import GROUPNAME, USERNAME, NAME_NIX, DIR_VAR, DIR_LOG, DIR_ETC, FILE_ADMINS, FILE_ENV, \
    FILE_CONF, FILE_SERVICE, NAME_SERVICE, DIR_ANGELOS, FILE_EXE, LINK_EXE



SCRIPTLET_PRE_INSTALL = """
grep {0} /etc/group 2>&1>/dev/null
if [ $? != 0 ]
then
  groupadd {0}
else
  printf "Group {0} already exists.\n"
fi

if id {1} >/dev/null 2>&1; then
  printf "User {1} already exists.\n"
else
  useradd {1} --system -g {0}
fi
""".format(GROUPNAME, USERNAME)

SCRIPTLET_POST_INSTALL = """
DATA_ENV_JSON=$(cat <<EOF
{{}}
EOF
)

DATA_CONFIG_JSON=$(cat <<EOF
{{}}
EOF
)

DATA_SYSTEMD_SERVICE=$(cat <<EOF
[Unit]
Description = Run the Angelos server
After = network.target

[Service]
Type = forking
AmbientCapabilities = CAP_NET_BIND_SERVICE

ExecStart = {namenix} -d start
ExecStop = {namenix} -d stop
ExecReload = {namenix} -d restart

User = {username}
Group = {groupname}

# RootDirectory = {dirangelos}
RuntimeDirectory = {namenix}
StateDirectory = {dirvar}
LogsDirectory = {dirlog}
ConfigurationDirectory = {diretc}

KeyringMode = private

[Install]
WantedBy=default.target
EOF
)

# Create directories for angelos
mkdir {dirvar} -p
mkdir {dirlog} -p
mkdir {diretc} -p

# Create admin public keys file
if [ -s "{fileadmins}" ]
then
   echo "{fileadmins} already exists, left untouched."
else
  echo "" > {fileadmins}
fi

# Create configuration
if [ -s "{fileenv}" ]
then
   echo "{fileenv} already exists, left untouched."
else
  echo $DATA_ENV_JSON > {fileenv}
fi

if [ -s "{fileconf}" ]
then
   echo "{fileconf} already exists, left untouched."
else
  echo $DATA_CONFIG_JSON > {fileconf}
fi

# Setup systemd service
if [ -s "{fileservice}" ]
then
   echo "{fileservice} already exists, left untouched."
else
  echo "$DATA_SYSTEMD_SERVICE" > {fileservice}
  chmod 644 {fileservice}
  systemctl daemon-reload
  systemctl enable
  echo "Run '>sudo systemctl start {nameservice}' in order to start angelos."
fi

# Set angelos:angelos ownership
chown -R {username}:{groupname} {dirangelos}
chown -R {username}:{groupname} {dirvar}
chown -R {username}:{groupname} {dirlog}
chown -R {username}:{groupname} {diretc}

# Make angelos binary accessible
ln -sf {fileexe} {linkexe}
""".format(
    namenix=NAME_NIX, dirvar=DIR_VAR, dirlog=DIR_LOG, diretc=DIR_ETC, fileadmins=FILE_ADMINS,
    fileenv=FILE_ENV, fileconf=FILE_CONF, fileservice=FILE_SERVICE, nameservice=NAME_SERVICE,
    username=USERNAME, groupname=GROUPNAME, dirangelos=DIR_ANGELOS, fileexe=FILE_EXE, linkexe=LINK_EXE
)

SCRIPTLET_PRE_UNINSTALL = """
# Remove systemd entry
systemctl stop {0}
systemctl disable {0}
rm {1}
systemctl daemon-reload

# Remove angelos link
rm {2}
""".format(NAME_SERVICE, FILE_SERVICE, LINK_EXE)

SCRIPTLET_POST_UNINSTALL = """
# Remove all angelos files
rm -fR {0}/*
rm -fR {1}/*

# Remove all angelos directories
rmdir {0}
rmdir {1}
""".format(DIR_ETC, DIR_ANGELOS)