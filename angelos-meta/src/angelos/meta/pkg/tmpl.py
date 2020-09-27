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

from .data import NAME_NIX, VERSION, LICENSE, URL, PERMS_DIR, PERMS_EXEC, PERMS_FILE, EXEC_PREFIX, DIR_ANGELOS
from .scripts import render_scriptlets

RPM_SPEC = """
Name: {namenix}
Version: {version}
Release: {release}
Summary: A safe messaging system.
License: {license}
URL: {url}
BuildArch: x86_64
BuildRequires: bzip2-devel, expat-devel, gdbm-devel, ncurses-devel, openssl-devel, readline-devel, sqlite-devel,
BuildRequires: tk-devel, xz-devel, zlib-devel, libffi-devel
Requires: bzip2-libs, expat, gdbm-libs, ncurses-libs, openssl-libs, readline, sqlite-libs, tk, xz-libs, zlib, libffi
AutoReqProv: no

# RPM error problem
# https://fedoraproject.org/wiki/Changes/Make_ambiguous_python_shebangs_error
BuildRequires: /usr/bin/pathfix.py

%description
 Ἄγγελος is a safe messenger system. Angelos means "Carrier of a divine message."

%prep

%build

%check

%install

mkdir %{{buildroot}}/opt -p
sudo mv /opt/angelos/ %{{buildroot}}/opt

# Shebang RPM error crash fix
pathfix.py -pni "%{{__python3}} %{{py3_shbang_opts}}" %{{buildroot}}/*

%clean

%pre
{preinst}

%post
{postinst}

%preun
{preuninst}

%postun
{postuninst}

%changelog

%files
{files}
"""


def walk_files(path: str) -> str:
    """Walk all files and directories at install path."""
    output = ""
    for root, dirs, files in os.walk(path):
        output += "%attr({perms}, angelos, angelos) {path}\n".format(
            perms=PERMS_DIR, path=root)
        for file in files:
            output += "%attr({perms}, angelos, angelos) {path}\n".format(
                perms=(PERMS_EXEC if root.startswith(EXEC_PREFIX) else PERMS_FILE),
                path=os.path.join(root, file)
            )
    return output


def render_rpm_spec(release: int, full_path: bool=True) -> str:
    """Render the RPM spec file."""
    preinst, postinst, preuninst, postuninst = render_scriptlets(full_path)
    return RPM_SPEC.format(
        preinst=preinst, postinst=postinst, preuninst=preuninst,
        postuninst=postuninst, namenix=NAME_NIX, url=URL, version=VERSION, release=release,
        license=LICENSE, files=walk_files(DIR_ANGELOS)
    )
