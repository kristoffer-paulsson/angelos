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
"""Scriptlets for packaging under pre-install, post-install, pre-uninstall and post-uninstall conditions."""

NAME_NIX = "angelos"
NAME_SERVICE = "{}.service".format(NAME_NIX)

USERNAME = "{}".format(NAME_NIX)
GROUPNAME = "{}".format(NAME_NIX)

DIR_ANGELOS = "/opt/{}".format(NAME_NIX)
DIR_VAR = "/var/lib/{}".format(NAME_NIX)
DIR_LOG = "/var/log/{}".format(NAME_NIX)
DIR_ETC = "/etc/{}".format(NAME_NIX)

LINK_EXE = "/usr/local/bin/{}".format(NAME_NIX)

FILE_EXE = "{0}/bin/{1}".format(DIR_ANGELOS, NAME_NIX)
FILE_ADMINS = "{0}/admins.pub".format(DIR_VAR)
FILE_ENV = "{}/env.json".format(DIR_ETC)
FILE_CONF = "{}/config.json".format(DIR_ETC)
FILE_SERVICE = "/etc/systemd/system/{}".format(NAME_SERVICE)

DATA_ENV_JSON = """
{}
"""

DATA_CONFIG_JSON = """
{}
"""

DATA_SYSTEMD_SERVICE = """
[Unit]
Description = Run the Angelos server
After = network.target

[Service]
Type = forking
AmbientCapabilities = CAP_NET_BIND_SERVICE

ExecStart = {0} -d start
ExecStop = {0} -d stop
ExecReload = {0} -d restart

User = {1}
Group = {2}

# RootDirectory = {3}
RuntimeDirectory = {0}
StateDirectory = {4}
LogsDirectory = {5}
ConfigurationDirectory = {6}

KeyringMode = private

[Install]
WantedBy=default.target
""".format(NAME_NIX, USERNAME, GROUPNAME, DIR_ANGELOS, DIR_VAR, DIR_LOG, DIR_ETC)

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

print("#" * 80)
print("%pre")
print(SCRIPTLET_PRE_INSTALL)
print("%post")
print(SCRIPTLET_POST_INSTALL)
print("%preun")
print(SCRIPTLET_PRE_UNINSTALL)
print("%postun")
print(SCRIPTLET_POST_UNINSTALL)
print("#" * 80)