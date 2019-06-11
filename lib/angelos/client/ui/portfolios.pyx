# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
from kivy.lang import Builder
from kivy.properties import StringProperty
from kivymd.dialog import BaseDialog

from .common import BasePanelScreen


Builder.load_string("""
#:import MDLabel kivymd.label.MDLabel
#:import MDRectangleFlatIconButton kivymd.button.MDRectangleFlatIconButton
#:import MDTextField kivymd.textfields.MDTextField
#:import MDBottomNavigation kivymd.bottomnavigation.MDBottomNavigation

<PortfolioImporter>:
    background_color: app.theme_cls.primary_color
    background: ''
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
                [['chevron-left', lambda x: root.dismiss()]]
        ScrollView:
            do_scroll_x: False
            BoxLayout:
                orientation: 'vertical'
                size_hint_y: None
                height: self.minimum_height
                padding: dp(25)
                spacing: dp(15)
                MDTextField:
                    text: root.data
                    valign: 'top'
                    multiline: True
                    hint_text: 'Portfolio data'
                    helper_text: 'You can enter multiline portfolio data here.'
                    helper_text_mode: 'persistent'
                MDRectangleFlatIconButton:
                    icon: 'file-import'
                    text: 'Import'
                    opposite_colors: True
                    elevation_normal: 8
                    # md_bg_color: app.theme_cls.primary_color


<PortfoliosScreen@BasePanelScreen>:
    name: 'portfolios'
    title: 'Portfolios'
    on_pre_enter: self.load()
    on_leave: self.unload()
    right_action_items:
        [['file-import', lambda x: root.import_portfolio()]]

""")  # noqa E501


class PortfolioImporter(BaseDialog):
    id = ''
    title = 'Portfolio importer'
    data = StringProperty()

    def load(self, app):
        """Prepare the message composer dialog box."""
        self._app = app


class PortfoliosScreen(BasePanelScreen):
    def import_portfolio(self):
        writer = PortfolioImporter()
        writer.load(self.app)
        writer.open()
