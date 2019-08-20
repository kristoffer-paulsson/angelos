# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Preferences classes and functions that are saved in vault.ar7.cnl.
/settings/preferences.ini
"""


class Preferences:
    def __init__(self, facade):
        self._facade = facade
        self._parser = None

    async def load(self):
        self._parser = await self._facade.settings.preferences()

    async def save(self):
        return await self._facade.settings.save_prefs(self._parser)

    @property
    def network(self):
        return self._parser.get(
            'Preferences', 'CurrentNetwork', fallback=None)

    @network.setter
    def network(self, value):
        self._parser.set('Preferences', 'CurrentNetwork', value)
