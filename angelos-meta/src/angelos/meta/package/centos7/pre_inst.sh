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

sudo mkdir /opt/angelos
sudo chown -R angelos:angelos /opt/angelos

sudo mkdir /var/lib/angelos
sudo chown -R angelos:angelos /var/lib/angelos

sudo mkdir /var/log/angelos
sudo chown -R angelos:angelos /var/log/angelos

sudo mkdir /etc/angelos
sudo chown -R angelos:angelos /etc/angelos