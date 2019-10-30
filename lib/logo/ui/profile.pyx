# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring"""
from kivy.lang import Builder
from kivy.properties import StringProperty
from kivy.core.clipboard import Clipboard
from kivymd.uix.dialog import BaseDialog
from kivymd.uix.snackbar import Snackbar

from libangelos.policy.portfolio import PGroup
from libangelos.operation.export import ExportImportOperation
from libangelos.archive.helper import Glue
from .common import BasePanelScreen


Builder.load_string("""
<PortfolioExporter>
    background_color: app.theme_cls.primary_color
    background: ''
    BoxLayout:
        orientation: 'vertical'
        MDToolbar:
            id: toolbar
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
                id: docs
                size_hint_y: None
                height: self.minimum_height
                padding: dp(25)
                spacing: dp(25)
                MDLabel:
                    text: root.data
                    size_hint_y: None
                    height: self.texture_size[1]
                    text_size: self.width, None
                    valign: 'top'
                MDRectangleFlatIconButton:
                    icon: 'content-copy'
                    text: 'Copy'
                    opposite_colors: True
                    elevation_normal: 8
                    on_release: root.copy()


<ProfileScreen@BasePanelScreen>:
    name: 'profile'
    title: 'Profile'
    on_pre_enter: self.load()
    on_leave: self.unload()
    right_action_items:
        [['file-export', lambda x: root.export_portfolio()]]
""")  # noqa E501


class PortfolioExporter(BaseDialog):
    id = ''
    title = 'Portfolio exporter'
    data = StringProperty()

    def load(self, app):
        """Prepare the message composer dialog box."""
        self._app = app
        portfolio = Glue.run_async(self._app.ioc.facade.load_portfolio(
            self._app.ioc.facade.portfolio.entity.id,
            PGroup.SHARE_MED_USER))
        self.data = ExportImportOperation.text_exp(portfolio)

    def copy(self):
        Clipboard.copy(self.data)
        Snackbar(text="Copied portfolio to clipboard.").show()


class ProfileScreen(BasePanelScreen):
    def export_portfolio(self):
        writer = PortfolioExporter()
        writer.load(self.app)
        writer.open()
