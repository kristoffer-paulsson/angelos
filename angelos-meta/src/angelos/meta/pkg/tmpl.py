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
"""Install file templates."""
import os
import re
import shutil

from .data import NAME_NIX, VERSION, LICENSE, URL, PERMS_DIR, PERMS_EXEC, PERMS_FILE, EXEC_PREFIX, DIR_ANGELOS, \
    FILE_ENV, FILE_CONF, FILE_EXE, USERNAME, GROUPNAME, NAME_SERVICE, DIR_VAR, DIR_LOG, DIR_ETC, FILE_ADMINS, LINK_EXE, \
    FILTER
from .scripts import render_scriptlets

RPM_SPEC = """
Name: {namenix}
Version: {version}
Release: {release}
Summary: A safe messaging system.
License: {license}
URL: {url}
Source1: angelos.service
Source2: env.json
Source3: config.json
Source4: admins.pub
BuildArch: x86_64
BuildRequires: bzip2-devel, expat-devel, gdbm-devel, ncurses-devel, openssl-devel, readline-devel, sqlite-devel,
BuildRequires: tk-devel, xz-devel, zlib-devel, libffi-devel
BuildRequires: systemd-rpm-macros /usr/bin/pathfix.py
Requires: bzip2-libs, expat, gdbm-libs, ncurses-libs, openssl-libs, readline, sqlite-libs, tk, xz-libs, zlib, libffi
AutoReqProv: no

%description
 Ἄγγελος is a safe messenger system. Angelos means "Carrier of a divine message."

%prep

%build

%check

%install
mkdir %{{buildroot}}/opt -p
sudo mv /opt/angelos/ %{{buildroot}}/opt

install --directory %{{buildroot}}{diretc}
install --directory %{{buildroot}}{dirvar}
install --directory %{{buildroot}}{dirlog}

install -D -m 0644 %{{SOURCE1}} %{{buildroot}}%{{_unitdir}}/{nameservice}
install -D -m 0644 %{{SOURCE2}} %{{buildroot}}{fileenv}
install -D -m 0644 %{{SOURCE3}} %{{buildroot}}{fileconf}
install -D -m 0644 %{{SOURCE4}} %{{buildroot}}{fileadmins}

pathfix.py -pni "%{{__python3}} %{{py3_shbang_opts}}" %{{buildroot}}/*

%clean

%pre
grep -q {groupname} /etc/group >/dev/null 2>&1 || groupadd {groupname}
id {username} >/dev/null 2>&1 || useradd {username} --system -g {groupname}

%post
%systemd_post {nameservice}
ln -sf {fileexe} {linkexe}

%preun
%systemd_preun {nameservice}
rm {linkexe}

%postun
%systemd_postun {nameservice}

%changelog

%files
%attr(700, {username}, {groupname}) {dirvar}
%attr(700, {username}, {groupname}) {dirlog}
%{{_unitdir}}/{nameservice}
%config {fileenv}
%config {fileconf}
%attr(600, -, -) {fileadmins}
%defattr({permsfile}, {username}, {groupname}, {permsdir})
{files}
"""


def walk_files(path: str) -> str:
    """Walk all files and directories at install path."""
    output = ""
    for root, dirs, files in os.walk(path):
        output += "{path}\n".format(
            perms=PERMS_DIR, path=root)
        for file in files:
            output += "%attr({perms}, {username}, {groupname}) {path}\n".format(
                perms=PERMS_EXEC, path=os.path.join(root, file),
                username=USERNAME, groupname=GROUPNAME
            ) if root.startswith(EXEC_PREFIX) else "{path}\n".format(
                path=os.path.join(root, file)
            )
    return output


def filter_files(path: str, subs: list = None):
    """Filter all files and directories."""
    pattern = "|".join(subs if subs else FILTER)
    for root, dirs, files in os.walk(path):
        for file in files:
            # Deal with file
            filepath = os.path.join(root, file)
            if re.search(pattern, filepath) and os.path.exists(filepath):
                try:
                    os.remove(filepath)
                    print("Deleted file:", filepath)
                except as e:
                    print(filepath, e)
        # Deal with directory
        if re.search(pattern, root) and os.path.exists(root):
            try:
                shutil.rmtree(root)
                print("Deleted directory:", root)

            except as e:
                print(root, e)


def render_rpm_spec(release: int, full_path: bool=True) -> str:
    """Render the RPM spec file. (angelos.spec)"""
    return RPM_SPEC.format(
        dirangelos=DIR_ANGELOS, dirvar=DIR_VAR, diretc=DIR_ETC, dirlog=DIR_LOG,
        fileenv=FILE_ENV, fileconf=FILE_CONF, fileexe=FILE_EXE, linkexe=LINK_EXE,
        fileadmins=FILE_ADMINS, permsexec=PERMS_EXEC, permsfile=PERMS_FILE, permsdir=PERMS_DIR,
        username=USERNAME, groupname=GROUPNAME, nameservice=NAME_SERVICE,
        namenix=NAME_NIX, url=URL, version=VERSION, release=release, license=LICENSE,
        files=walk_files(DIR_ANGELOS)
    )


SYSTEMD_UNIT = """
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

StateDirectory = {service_dirvar}
LogsDirectory = {service_dirlog}
ConfigurationDirectory = {service_diretc}

KeyringMode = private

[Install]
WantedBy=default.target
"""


def render_systemd_unit(service_full_path: bool=True) -> str:
    """Render systemd unit file. (angelos.service)"""
    return SYSTEMD_UNIT.format(
        namenix=NAME_NIX, username=USERNAME, groupname=GROUPNAME,
        service_dirvar=DIR_VAR if service_full_path else NAME_NIX,
        service_dirlog=DIR_LOG if service_full_path else NAME_NIX,
        service_diretc=DIR_ETC if service_full_path else NAME_NIX
    )


ENV_JSON = """{{}}"""


def render_env_json() -> str:
    """Render env configuration file. (env.json)"""
    return ENV_JSON.format(
    )


CONFIG_JSON = """{{}}"""


def render_config_json() -> str:
    """Render config configuration file. (config.json)"""
    return CONFIG_JSON.format(
    )


ADMINS_PUB = """"""


def render_admins_pub() -> str:
    """Render admins public key file. (admins.pub)"""
    return ADMINS_PUB.format(
    )
