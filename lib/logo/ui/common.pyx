# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring"""
import logging
from typing import Callable, Any, Iterable
from functools import partial

from kivy.lang import Builder
from kivy.clock import Clock
from kivy.uix.widget import Widget
from kivy.uix.screenmanager import Screen
from kivy.uix.scrollview import ScrollView

from kivymd.uix.label import MDLabel
from kivymd.uix.list import MDList, BaseListItem

from libangelos.policy.portfolio import PrivatePortfolio


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
        BoxLayout:
            id: panel
            orientation: 'vertical'
""")  # noqa E501


class BasePanelScreen(Screen):
    def __init__(self, app, **kwargs):
        Screen.__init__(self, **kwargs)
        self.app = app

    def load(self):
        logging.error('\'load\' not implemented')

    def unload(self):
        logging.error('\'unload\' not implemented')

    def list_loader(
            self, itemlist: Iterable, widget: Widget,
            item_loader: Callable[[PrivatePortfolio, Any], BaseListItem]):
        """Will generate a list with items loaded from storage."""
        sv = ScrollView()
        mdl = MDList()
        sv.add_widget(mdl)
        widget.add_widget(sv)

        Clock.schedule_once(
            partial(self.load_list_item, itemlist, mdl, item_loader))
        return mdl

    def load_list_item(
            self, itemlist: Iterable, mdl: MDList,
            item_loader: Callable[[PrivatePortfolio, Any], BaseListItem], dt):
        """Load one item to put in list from storage."""
        listitem = itemlist.pop()
        item = item_loader(self.app.ioc.facade.portfolio, listitem)
        if item:
            mdl.add_widget(item)

        if itemlist:
            Clock.schedule_once(
                partial(self.load_list_item, itemlist, mdl, item_loader))


Builder.load_string("""
<EmptyList>:
    text: ''
    markup: True
    halign: 'center'
    valign: 'middle'
""")  # noqa E501


class EmptyList(MDLabel):
    pass


class AppGetter:
    def get_app(self):
        instance = self

        while hasattr(instance, 'parent') and not hasattr(instance, 'app'):
            instance = instance.parent

        return instance.app
