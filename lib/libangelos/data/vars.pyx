# cython: language_level=3
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
"""Built in variables."""

PREFERENCES_INI = b"""
[Preferences]
NightMode=True
[Client]
CurrentNetwork=None
[Server]
; The preselected network to connect to.
"""

"""
RSA keys for the boot and shell server.
This RSA key is the official private key of the server, it should either only
be used as a dummy under development or as a default key for installed, but
unconfigured servers.
"""
