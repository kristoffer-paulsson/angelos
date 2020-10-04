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

# Creates user and group for Angelos install.
[ -z ${USERNAME} ] && echo "USERNAME is not set!" && exit 1
[ -z ${GROUP} ] && echo "GROUP is not set!" && exit 1

grep -q $GROUP /etc/group >/dev/null 2>&1 || groupadd $GROUP
id $USERNAME >/dev/null 2>&1 || useradd $USERNAME --system -g $GROUP
