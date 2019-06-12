# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
from kivy.lang import Builder
from kivy.uix.image import AsyncImage
from kivymd.label import MDLabel
from kivymd.selectioncontrols import MDCheckbox
from kivymd.list import (
    OneLineAvatarIconListItem, MDList, ILeftBody, IRightBodyTouch)

from .common import BasePanelScreen


Builder.load_string("""
#:import MDLabel kivymd.label.MDLabel
#:import MDCheckbox kivymd.selectioncontrols.MDCheckbox
#:import MDBottomNavigation kivymd.bottomnavigation.MDBottomNavigation


<EmptyList>:
    text: ''
    markup: True
    halign: 'center'
    valign: 'middle'


<ContactListItem>:
    text: '<Anonymous entity>'
    on_press: root.show_menu(app)


<ContactsScreen@BasePanelScreen>:
    name: 'contacts'
    title: 'Contacts'
    on_pre_enter: self.load()
    on_leave: self.unload()
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
            right_action_items: []
        MDBottomNavigation
            id: bottom_nav
            tab_display_mode: 'icons'
            MDBottomNavigationItem:
                name: 'favorites'
                text: 'Favorites'
                icon: 'star'
                on_pre_enter: root.list_favorites()
                on_leave: print('On leave')
            MDBottomNavigationItem:
                name: 'friends'
                text: 'Friends'
                icon: 'heart'
                on_pre_enter: root.list_friends()
                on_leave: print('On leave')
            MDBottomNavigationItem:
                name: 'church'
                text: 'Church'
                icon: 'church'
                on_pre_enter: root.list_church()
                on_leave: print('On leave')
            MDBottomNavigationItem:
                name: 'blocked'
                text: 'Blocked'
                icon: 'block-helper'
                on_pre_enter: root.list_blocked()
                on_leave: print('On leave')
            MDBottomNavigationItem:  # Button to empty trash
                name: 'all'
                text: 'All'
                icon: 'account-multiple'
                on_pre_enter: root.list_all()
                on_leave: print('On leave')
""")  # noqa E501


class EmptyList(MDLabel):
    pass


class AvatarLeftWidget(ILeftBody, AsyncImage):
    pass


class IconRightMenu(IRightBodyTouch, MDCheckbox):
    pass


class DummyPhoto(ILeftBody, AsyncImage):
        pass


class ContactListItem(OneLineAvatarIconListItem):
    entity_id = None


class ContactsScreen(BasePanelScreen):
    def list_favorites(self):
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('favorites')

    def list_friends(self):
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('friends')

    def list_church(self):
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('church')

    def list_blocked(self):
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('blocked')

    def list_all(self):
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('all')
