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

DIRECTORY_STRUCTURE = [
    "SOURCES",
    "SPECS",
    "BUILD",
    "RPMS",
    "SRPMS"
]

COPYRIGHT_NOTICE = """
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
"""

# Filename should be: SPECS/{name}-{version}.spec
# Build by: rpmbuild -ba {name}-{version}.spec
TMPL_SPEC = """
Summary: Ἄγγελος is a safe messenger system.
Name: {name}
Version: {version}
Release: {release}
License: MIT
Group: Applications/Sound
Source: https://github.com/kristoffer-paulsson/angelos/archive/{version}.zip
URL: https://github.com/kristoffer-paulsson/angelos
Distribution: CentOS
Vendor: Kristoffer Paulsson
Packager: Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

%description
The goal of this project is to design and develop a server and app
communications platform. This social media platform targets smartphones,
tablets, desktop computers, and the server software to be installable on
Linux and Windows servers.

%prep
# Scripts and commands that prepares the build process
# Create the build environment

%setup
# Find out later for what.

%build
# Build commands

%clean
# Clean up after build outside build directory

%install
# Install commands

%files
# All files to be installed must be listed here
# Documentation file should be marked %doc <file>
"""