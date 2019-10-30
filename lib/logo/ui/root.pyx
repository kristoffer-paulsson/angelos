# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring"""
import logging

from kivy.lang import Builder
from kivy.uix.screenmanager import Screen

from .common import BasePanelScreen
from .messages import MessagesScreen
from .contacts import ContactsScreen
from .portfolios import PortfoliosScreen
from .networks import NetworksScreen
from .profile import ProfileScreen


Builder.load_string("""
<FilesScreen@BasePanelScreen>:
    name: 'files'
    title: 'Files'
    on_pre_enter: self.load()
    on_leave: self.unload()
""")  # noqa E501


class FilesScreen(BasePanelScreen):
    pass


Builder.load_string("""
<SettingsScreen@BasePanelScreen>:
    name: 'settings'
    title: 'Settings'
    on_pre_enter: self.load()
    on_leave: self.unload()
""")  # noqa E501


class SettingsScreen(BasePanelScreen):
    pass


Builder.load_string("""
<MainScreen@Screen>:
    name: 'main'
    # on_pre_enter: self.load()
    # on_leave: self.unload()
    BoxLayout:
        orientation: 'vertical'
        MDToolbar:
            id: toolbar
            title: 'Logo messenger'
            md_bg_color: app.theme_cls.bg_light
            background_palette: 'Primary'
            background_hue: '500'
            elevation: 10
            left_action_items:
                [['menu', lambda x: root.parent.parent.parent.toggle_nav_drawer()]]
        MDBottomNavigation:
            MDBottomNavigationItem:
                name: 'home'
                text: 'Home'
                icon: 'home'
                Widget:
            MDBottomNavigationItem:
                name: 'search'
                text: 'Search'
                icon: 'magnify'
                Widget:
            MDBottomNavigationItem:
                name: 'notes'
                text: 'Notice'
                icon: 'bell'
                Widget:
            MDBottomNavigationItem:
                name: 'messages'
                text: 'Inbox'
                icon: 'inbox'
                Widget:
""")  # noqa E501


class MainScreen(Screen):
    def __init__(self, app, **kwargs):
        Screen.__init__(self, **kwargs)
        self.app = app

    def load(self):
        logging.error('\'load\' not implemented')

    def unload(self):
        logging.error('\'unload\' not implemented')


Builder.load_string("""
<ContentNavigationDrawer@MDNavigationDrawer>:
    NavigationDrawerIconButton:
        text: 'Messages'
        icon: 'email-outline'
        on_release: root.ids.scr_mngr.current = 'messages'
    NavigationDrawerIconButton:
        text: 'Contacts'
        icon: 'contact-mail'
        on_release: root.ids.scr_mngr.current = 'contacts'
    NavigationDrawerIconButton:
        text: 'Portfolios'
        icon: 'shield-account'
        on_release: root.ids.scr_mngr.current = 'portfolios'
    NavigationDrawerIconButton:
        text: 'Files'
        icon: 'folder-account'
        on_release: root.ids.scr_mngr.current = 'files'
    NavigationDrawerIconButton:
        text: 'Networks'
        icon: 'domain'
        on_release: root.ids.scr_mngr.current = 'networks'
    NavigationDrawerIconButton:
        text: 'Profile'
        icon: 'face-profile'
        on_release: root.ids.scr_mngr.current = 'profile'
    NavigationDrawerIconButton:
        text: 'Settings'
        icon: 'settings'
        on_release: root.ids.scr_mngr.current = 'settings'

<UserScreen@Screen>
    NavigationLayout:
        id: nav_layout
        MDNavigationDrawer:
            id: nav_drawer
            drawer_logo: './art/angelos.png'
            drawer_title: 'Hello world'
            NavigationDrawerIconButton:
                text: 'Dashboard'
                icon: 'monitor-dashboard'
                on_release: root.goto_main(app)
            NavigationDrawerIconButton:
                text: 'Messages'
                icon: 'email-outline'
                on_release: root.goto_messages(app)
            NavigationDrawerIconButton:
                text: 'Contacts'
                icon: 'contact-mail'
                on_release: root.goto_contacts(app)
            NavigationDrawerIconButton:
                text: 'Portfolios'
                icon: 'briefcase-check'
                on_release: root.goto_portfolios(app)
            NavigationDrawerIconButton:
                text: 'Documents'
                icon: 'folder-account'
                on_release: root.goto_files(app)
            NavigationDrawerIconButton:
                text: 'Networks'
                icon: 'domain'
                on_release: root.goto_networks(app)
            NavigationDrawerIconButton:
                text: 'Profile'
                icon: 'face-profile'
                on_release: root.goto_profile(app)
            NavigationDrawerIconButton:
                text: 'Settings'
                icon: 'settings'
                on_release: root.goto_settings(app)
        ScreenManager:
            id: scr_mngr
            MainScreen:
""")  # noqa E501


class UserScreen(Screen):
    def goto_main(self, app):
        if self.ids.scr_mngr.current != 'main':
            self.switch(MainScreen(app, name='main'))

    def goto_messages(self, app):
        if self.ids.scr_mngr.current != 'messages':
            self.switch(MessagesScreen(app, name='messages'))

    def goto_contacts(self, app):
        if self.ids.scr_mngr.current != 'contacts':
            self.switch(ContactsScreen(app, name='contacts'))

    def goto_portfolios(self, app):
        if self.ids.scr_mngr.current != 'portfolios':
            self.switch(PortfoliosScreen(app, name='portfolios'))

    def goto_files(self, app):
        if self.ids.scr_mngr.current != 'files':
            self.switch(FilesScreen(app, name='files'))

    def goto_networks(self, app):
        if self.ids.scr_mngr.current != 'networks':
            self.switch(NetworksScreen(app, name='networks'))

    def goto_profile(self, app):
        if self.ids.scr_mngr.current != 'profile':
            self.switch(ProfileScreen(app, name='profile'))

    def goto_settings(self, app):
        if self.ids.scr_mngr.current != 'settings':
            self.switch(SettingsScreen(app, name='settings'))

    def switch(self, screen):
        """Switch to another main screen."""
        old = self.ids.scr_mngr.current

        self.ids.scr_mngr.add_widget(screen)
        self.ids.scr_mngr.current = screen.name

        screen = self.ids.scr_mngr.get_screen(old)
        self.ids.scr_mngr.remove_widget(screen)
