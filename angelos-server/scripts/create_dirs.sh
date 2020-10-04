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

# Creates directories for Angelos install.
[ -z ${DESTDIR} ] && echo "DESTDIR is not set!" && exit 1
[ -z ${PACKAGE} ] && echo "PACKAGE is not set!" && exit 1

mkdir -p $(DESTDIR)/etc/$(PACKAGE)
mkdir -p $(DESTDIR)/var/lib/$(PACKAGE)
mkdir -p $(DESTDIR)/var/log/$(PACKAGE)