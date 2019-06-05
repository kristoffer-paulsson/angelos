# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
from kivy.lang import Builder
from kivy.properties import StringProperty
from kivy.clock import Clock
from kivy.uix.scrollview import ScrollView
from kivy.uix.image import AsyncImage
from kivymd.label import MDLabel
from kivymd.list import (
    TwoLineAvatarListItem, MDList, ILeftBody, IRightBodyTouch)
from kivymd.popupscreen import MDPopupScreen
from kivymd.dialog import BaseDialog
from kivymd.button import MDIconButton
from kivymd.menus import MDDropdownMenu

from ...archive.helper import Glue
from ...policy import EnvelopePolicy, PGroup, PrintPolicy
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


<InboxItem>:
    text: '<Unknown subject>'
    secondary_text: '<Unkown sender>'
    on_press: root.show_message(app)


<ReadMessage>:
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
            right_action_items:
                [['alert-circle-outline',  lambda x: root.dismiss()], ['reply',  lambda x: root.dismiss()]]
        BoxLayout:
            orientation: 'vertical'
            MDList:
                TwoLineAvatarIconListItem:
                    text: root.subject
                    secondary_text: '[size=14sp][b]' + root.sender + '[/b] - ' + root.posted + '[/size]'
                    markup: True
                    AvatarLeftWidget:
                        source: './data/icon_72x72.png'
                    IconRightMenu:
                        icon: 'dots-horizontal'
                        on_release: root.dropdown(self)
            ScrollView:
                do_scroll_x: False
                MDLabel:
                    text: root.body
                    line_height: 2.0
                    padding: dp(25), dp(25)
                    size_hint_y: None
                    height: self.texture_size[1]
                    text_size: self.width, None
                    valign: 'top'


<WriteMessage>:


<MessagesScreen@BasePanelScreen>:
    id: 'messages'
    title: 'Messages'
    on_enter: self.load()
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


class AvatarLeftWidget(ILeftBody, AsyncImage):
    pass


class IconRightMenu(IRightBodyTouch, MDIconButton):
    pass


class EmptyInbox(MDLabel):
    pass


class DummyPhoto(ILeftBody, AsyncImage):
        pass


class InboxItem(TwoLineAvatarListItem):
    envelope_id = None

    def show_message(self, app):
        self.parent.remove_widget(self)

        reader = ReadMessage()
        reader.load(app, self.envelope_id)
        reader.open()


class ReadMessage(BaseDialog):
    id = ''
    title = 'Inbox message'
    sender = StringProperty()
    posted = StringProperty()
    subject = StringProperty()
    body = StringProperty()

    def load(self, app, message_id):
        mail = app.ioc.facade.mail
        self._msg = Glue.run_async(mail.load_message(message_id))

        if self._msg:
            self._sender = Glue.run_async(app.ioc.facade.load_portfolio(
                self._msg.issuer, PGroup.VERIFIER))
            self.subject = '[b]' + self._msg.subject + '[/b]'
            self.body = self._msg.body
            self.sender = PrintPolicy.title(self._sender)
            self.posted = '{:%c}'.format(self._msg.posted)
        else:
            self._env = Glue.run_async(mail.load_envelope(message_id))
            self._sender = Glue.run_async(app.ioc.facade.load_portfolio(
                self._env.issuer, PGroup.VERIFIER))
            self._msg = EnvelopePolicy.open(
                app.ioc.facade.portfolio, self._sender, self._env)
            self.subject = '[b]' + self._msg.subject + '[/b]'
            self.body = self._msg.body
            self.sender = PrintPolicy.title(self._sender)
            self.posted = '{:%c}'.format(self._msg.posted)

    def dropdown(self, anchor):
        return MDDropdownMenu(
            items=[
                {
                    'viewclass': 'MDMenuItem',
                    'text': 'Reply to',
                    'callback': self.ddm_reply,
                }, {
                    'viewclass': 'MDMenuItem',
                    'text': 'Forward to',
                    'callback': self.ddm_forward,
                }, {
                    'viewclass': 'MDMenuItem',
                    'text': 'Share with',
                    'callback': self.ddm_share,
                }, {
                    'viewclass': 'MDMenuItem',
                    'text': 'Compose new',
                    'callback': self.ddm_compose,
                }
            ],
            width_mult=3).open(anchor)

    def ddm_reply(self, arg):
        print(arg)

    def ddm_forward(self, arg):
        print(arg)

    def ddm_compose(self, arg):
        print(arg)

    def ddm_share(self, arg):
        print(arg)

    def ddm_report(self, arg):
        print(arg)


class WriteMessage(MDPopupScreen):
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
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('inbox')
        widget.clear_widgets()

        if not messages:
            widget.add_widget(EmptyInbox())
            return

        sv = ScrollView()
        ml = MDList()
        sv.add_widget(ml)
        widget.add_widget(sv)

        portfolio = self.app.ioc.facade.portfolio
        for msg in messages:
            if isinstance(msg[1], type(None)):
                try:
                    sender = Glue.run_async(self.app.ioc.facade.load_portfolio(
                        msg[0].issuer, PGroup.VERIFIER))
                    message = EnvelopePolicy.open(portfolio, sender, msg[0])
                    headling = message.subject
                    title = PrintPolicy.title(sender)
                    source = './data/icon_72x72.png'
                except OSError:
                    headling = '<Unknown>'
                    title = '<Unidentified sender>'
                    source = './data/anonymous.png'
                # if message.type == DocType.COM_NOTE:
                #    pass
                # elif message.type == DocType.COM_MAIL:
                #    pass
                # elif message.type == DocType.COM_SHARE:
                #    pass
                # elif message.type == DocType.COM_REPORT:
                #    pass
                inboxitem = InboxItem(
                    text=headling,
                    secondary_text=title,
                )
                inboxitem.envelope_id = msg[0].id
                inboxitem.add_widget(DummyPhoto(source=source))
                ml.add_widget(inboxitem)
            else:
                print(msg)
