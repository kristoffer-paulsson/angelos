# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
from kivy.lang import Builder
from kivy.clock import Clock
from kivymd.label import MDLabel

from ...archive.helper import Glue
from .common import BasePanelScreen


Builder.load_string("""
#:import MDLabel kivymd.label.MDLabel
#:import MDCheckbox kivymd.selectioncontrols.MDCheckbox
#:import MDTextField kivymd.textfields.MDTextField
#:import MDBottomNavigation kivymd.bottomnavigation.MDBottomNavigation

#:import MDScrollViewRefreshLayout kivymd.refreshlayout.MDScrollViewRefreshLayout


<EmptyInbox>:
    text: 'The inbox is empty!\\n[size=14sp][i]Check for messages on the network\\nby pull-and-release.[/i][/size]'
    markup: True
    halign: 'center'
    valign: 'middle'


<MessagesScreen@BasePanelScreen>:
    id: 'messages'
    title: 'Messages'
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
            right_action_items:
                [['dots-vertical', lambda x: root.menu(root.ids.bottom_nav.ids.tab_manager.current)]]
        MDBottomNavigation
            id: bottom_nav
            tab_display_mode: 'icons'
            MDBottomNavigationItem:
                name: 'inbox'
                text: "Inbox"
                icon: 'inbox-arrow-down'
                on_pre_enter: root.get_inbox()
                on_leave: print('On leave')
                # MDScrollViewRefreshLayout:
                #    id: refresh_inbox
                #    refresh_callback: root.refresh_callback
                #    root_layout: self
                #    MDLabel:
                #        font_style: 'Body1'
                #        theme_text_color: 'Primary'
                #        text: 'I love Python'
                #        halign: 'center'
            MDBottomNavigationItem:
                name: 'outbox'
                text: "Outbox"
                icon: 'inbox-arrow-up'
                BoxLayout:
            MDBottomNavigationItem:
                name: 'drafts'
                text: "Drafts"
                icon: 'file-multiple'
                BoxLayout:
            MDBottomNavigationItem:
                name: 'read'
                text: "Read"
                icon: 'email-open'
                BoxLayout:
            MDBottomNavigationItem:  # Button to empty trash
                name: 'trash'
                text: "Trash"
                icon: 'delete'
                BoxLayout:
""")  # noqa E501


class EmptyInbox(MDLabel):
    pass


class MessagesScreen(BasePanelScreen):
    def load(self):
        self.get_inbox()
        print('Load:', type(self))

    def unload(self):
        print('Unload:', type(self))

    def menu(self, name):
        """Show appropriate menu for each tab."""
        print('Menu for:', name)

    def refresh_callback(self, *args):
        '''A method that updates the state of your application
        while the spinner remains on the screen.'''
        print(args)

        def refresh_callback(interval):
            self.ids.box.clear_widgets()
            if self.x == 0:
                self.x, self.y = 15, 30
            else:
                self.x, self.y = 0, 15
            # self.set_list()
            self.ids.refresh_layout.refresh_done()
            self.tick = 0
        Clock.schedule_once(refresh_callback, 1)

    def get_inbox(self):
        messages = Glue.run_async(self.app.ioc.facade.mail.load_inbox())
        print(messages)
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('inbox')
        if not messages:
            widget.add_widget(EmptyInbox())
            return
        for msg in messages:
            print(msg)
            if isinstance(msg[1], type(None)):
                pass
            else:
                pass
