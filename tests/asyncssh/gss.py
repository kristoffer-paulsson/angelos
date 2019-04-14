# Copyright (c) 2017-2018 by Ron Frederick <ronf@timeheart.net> and others.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License v2.0 which accompanies this
# distribution and is available at:
#
#     http://www.eclipse.org/legal/epl-2.0/
#
# This program may also be made available under the following secondary
# licenses when the conditions for such availability set forth in the
# Eclipse Public License v2.0 are satisfied:
#
#    GNU General Public License, Version 2.0, or any later versions of
#    that license
#
# SPDX-License-Identifier: EPL-2.0 OR GPL-2.0-or-later
#
# Contributors:
#     Ron Frederick - initial implementation, API, and documentation

"""GSSAPI wrapper"""

import sys

try:
    # pylint: disable=unused-import

    if sys.platform == 'win32': # pragma: no cover
        from .gss_win32 import GSSError, GSSClient, GSSServer
    else:
        from .gss_unix import GSSError, GSSClient, GSSServer

    gss_available = True
except ImportError: # pragma: no cover
    gss_available = False

    class GSSError(ValueError):
        """Stub class for reporting that GSS is not available"""

        def __init__(self, maj_code=0, min_code=0, token=None):
            super().__init__('GSS not available')

            self.maj_code = maj_code
            self.min_code = min_code
            self.token = token


    class GSSClient:
        """Stub client class for reporting that GSS is not available"""

        def __init__(self, host, delegate_creds):
            # pylint: disable=unused-argument

            raise GSSError()


    class GSSServer:
        """Stub client class for reporting that GSS is not available"""

        def __init__(self, host):
            # pylint: disable=unused-argument

            raise GSSError()
