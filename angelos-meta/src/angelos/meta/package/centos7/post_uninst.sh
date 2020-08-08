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

sudo rm -fR /opt/angelos/*
sudo rmdir /opt/angelos

sudo rm -fR /var/lib/angelos/*
sudo rmdir /var/lib/angelos

sudo rm -fR /var/log/angelos/*
sudo rmdir /var/log/angelos

sudo rm -fR /etc/angelos/*
sudo rmdir /etc/angelos
