# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import logging

from kivy.lang import Builder
from kivy.uix.screenmanager import Screen


Builder.load_string("""
<BasePanelScreen@Screen>:
    title: ''
    id: ''
    right_action_items: []
    BoxLayout:
        orientation: 'vertical'
        MDToolbar:
            id: root.id
            title: root.title
            md_bg_color: app.theme_cls.primary_color
            background_palette: 'Primary'
            background_hue: '500'
            elevation: 10
            left_action_items:
                [['menu', lambda x: root.parent.parent.parent.toggle_nav_drawer()]]
            right_action_items: root.right_action_items
        Widget:
""")  # noqa E501


class BasePanelScreen(Screen):
    def __init__(self, app, **kwargs):
        Screen.__init__(self, **kwargs)
        self.app = app

    def load(self):
        logging.error('\'load\' not implemented')

    def unload(self):
        logging.error('\'unload\' not implemented')
