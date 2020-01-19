# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
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
