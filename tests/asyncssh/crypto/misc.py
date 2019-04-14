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

"""Miscellaneous PyCA utility classes and functions"""

class PyCAKey:
    """Base class for PyCA private/public keys"""

    def __init__(self, pyca_key):
        self._pyca_key = pyca_key

    @property
    def pyca_key(self):
        """Return the PyCA object associated with this key"""

        return self._pyca_key
