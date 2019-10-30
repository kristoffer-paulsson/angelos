# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring"""
import logging
import pprint

from kivy.lang import Builder
from kivy.properties import StringProperty
from kivymd.uix.dialog import BaseDialog
from kivymd.uix.snackbar import Snackbar
from kivymd.uix.label import MDLabel

from .common import BasePanelScreen
from libangelos.operation.export import ExportImportOperation
from libangelos.archive.helper import Glue


Builder.load_string("""
<DocView@MDLabel>:
    size_hint_y: None
    height: self.texture_size[1]
    text_size: self.width, None
    valign: 'top'


<PortfolioView>
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
                    text: 'Look through the documents and see if you wish to save them.'
                    valign: 'top'
                MDRectangleFlatIconButton:
                    icon: 'content-save-all'
                    text: 'Save'
                    opposite_colors: True
                    elevation_normal: 8
                    on_release: root.save()


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
                spacing: dp(25)
                MDLabel:
                    text: 'Paste the information from the portfolio in the text-field to import the data.'
                    valign: 'top'
                MDTextField:
                    id: data
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
                    on_release: root.parse()


<PortfoliosScreen@BasePanelScreen>:
    name: 'portfolios'
    title: 'Portfolios'
    on_pre_enter: self.load()
    on_leave: self.unload()
    right_action_items:
        [['file-import', lambda x: root.import_portfolio()]]

""")  # noqa E501


class DocView(MDLabel):
    pass


class PortfolioView(BaseDialog):
    id = ''
    title = 'View portfolio'

    def load(self, app, portfolio):
        """Prepare the message composer dialog box."""
        self._app = app
        self._portfolio = portfolio

        issuer, owner = portfolio.to_sets()
        for doc in issuer | owner:
            dw = DocView()
            dw.text = doc.__class__.__name__ + '\n' + pprint.pformat(
                doc.export_yaml())
            self.ids.docs.add_widget(dw)

    def save(self):
        try:
            try:
                result, rejected, removed = Glue.run_async(
                    self._app.ioc.facade.import_portfolio(self._portfolio))
            except OSError as e:
                result, rejected, removed = Glue.run_async(
                    self._app.ioc.facade.update_portfolio(self._portfolio))

            self.dismiss()
            if result and not rejected and not removed:
                Snackbar(text="Success importing portfolio.").show()
            else:
                raise OSError('Facade import failed')
        except Exception as e:
            Snackbar(text="Failed importing portfolio.").show()
            logging.exception(e)


class PortfolioImporter(BaseDialog):
    id = ''
    title = 'Portfolio importer'
    data = StringProperty()

    def load(self, app):
        """Prepare the message composer dialog box."""
        self._app = app

    def parse(self):
        try:
            portfolio = ExportImportOperation.text_imp(self.ids['data'].text)

            pw = PortfolioView()
            pw.load(self._app, portfolio)
            pw.open()
            self.dismiss()
        except Exception as e:
            Snackbar(text="Failed parsing portfolio data.").show()
            logging.exception(e)


class PortfoliosScreen(BasePanelScreen):
    def import_portfolio(self):
        writer = PortfolioImporter()
        writer.load(self.app)
        writer.open()
