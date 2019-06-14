# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
from kivy.lang import Builder

from .common import BasePanelScreen


Builder.load_string("""
<NetworksScreen@BasePanelScreen>:
    name: 'networks'
    title: 'Networks'
    on_pre_enter: self.load()
    on_leave: self.unload()
    right_action_items:
        [['reload', lambda x: app.index_networks()]]
""")  # noqa E501


class NetworksScreen(BasePanelScreen):
    pass
