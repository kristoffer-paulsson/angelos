# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring"""
from typing import List, Any
from functools import partial

from kivy.lang import Builder
from kivy.properties import StringProperty
from kivy.clock import Clock
from kivy.uix.scrollview import ScrollView
from kivy.uix.image import AsyncImage
from kivymd.uix.label import MDLabel
from kivymd.uix.list import (
    TwoLineAvatarListItem, MDList, ILeftBody, IRightBodyTouch)
from kivymd.uix.dialog import BaseDialog
from kivymd.uix.button import MDIconButton
from kivymd.uix.menu import MDDropdownMenu

from libangelos.document.messages import Mail
from libangelos.archive.helper import Glue
from libangelos.policy.message import EnvelopePolicy, MessagePolicy
from libangelos.policy.portfolio import PGroup, PrivatePortfolio, Portfolio
from libangelos.policy.print import PrintPolicy
from libangelos.operation.mail import MailOperation
from .common import BasePanelScreen


Builder.load_string("""
<EmptyList>:
    text: ''
    markup: True
    halign: 'center'
    valign: 'middle'


<MsgListItem>:
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
                [['alert-circle-outline',  lambda x: root.dismiss()], ['reply',  lambda x: root.ddm_reply(0)]]
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
                [['content-save',  lambda x: root.save()], ['send',  lambda x: root.send()]]
        ScrollView:
            do_scroll_x: False
            BoxLayout:
                orientation: 'vertical'
                MDList:
                    OneLineAvatarListItem:
                        text: root.recipient
                        markup: True
                        AvatarLeftWidget:
                            source: './data/icon_72x72.png'
                BoxLayout:
                    orientation: 'vertical'
                    valign: 'top'
                    padding: dp(25), dp(25)
                    MDTextField:
                        text: root.subject
                        id: subject
                        hint_text: 'Subject'
                    MDTextField:
                        id: body
                        hint_text: 'Message'
                        multiline: True
                    Widget:

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
                [['reload', lambda x: app.check_mail()]]
                # [['email-plus-outline', lambda x: root.menu(root.ids.bottom_nav.ids.tab_manager.current)]]
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
                on_pre_enter: root.get_outbox()
                on_leave: print('On leave')
            MDBottomNavigationItem:
                name: 'drafts'
                text: "Drafts"
                icon: 'file-multiple'
                on_pre_enter: root.get_drafts()
                on_leave: print('On leave')
            MDBottomNavigationItem:
                name: 'read'
                text: "Read"
                icon: 'email-open'
                on_pre_enter: root.get_read()
                on_leave: print('On leave')
            MDBottomNavigationItem:  # Button to empty trash
                name: 'trash'
                text: "Trash"
                icon: 'delete'
                on_pre_enter: root.get_trash()
                on_leave: print('On leave')
""")  # noqa E501


class AvatarLeftWidget(ILeftBody, AsyncImage):
    pass


class IconRightMenu(IRightBodyTouch, MDIconButton):
    pass


EMPTY_INBOX = """The inbox is empty!\n[size=14sp][i]Check for messages on the network\nby pull-and-release.[/i][/size]"""  # noqa E501
EMPTY_OUTBOX = """The outbox is empty!\n[size=14sp][i]This list emtpies when you\nsend the mails to the network.[/i][/size]"""  # noqa E501
EMPTY_DRAFTS = """There is no drafts!\n[size=14sp][i]Drafts are saved here\nuntil you send them.[/i][/size]"""  # noqa E501
EMPTY_READ = """There is no read message!\n[size=14sp][i]This list fills up when you\nstart reading your inbox.[/i][/size]"""  # noqa E501
EMPTY_TRASH = """No garbage in the trash!\n[size=14sp][i]This list fills up when you\nstart throwing messages away.[/i][/size]"""  # noqa E501


class EmptyList(MDLabel):
    pass


class DummyPhoto(ILeftBody, AsyncImage):
        pass


class MsgListItem(TwoLineAvatarListItem):
    msg_id = None

    def show_message(self, app):
        self.parent.remove_widget(self)

        reader = ReadMessage()
        reader.load(app, self.msg_id)
        reader.open()


class ReadMessage(BaseDialog):
    id = ''
    title = 'Inbox message'
    sender = StringProperty()
    posted = StringProperty()
    subject = StringProperty()
    body = StringProperty()

    def load(self, app, message_id):
        self._app = app
        mail = app.ioc.facade.mail
        self._msg = Glue.run_async(mail.load_message(message_id))

        if self._msg:
            self._sender = Glue.run_async(app.ioc.facade.load_portfolio(
                self._msg.issuer, PGroup.VERIFIER))
        else:
            self._msg, self._sender = Glue.run_async(
                MailOperation.open_envelope(app.ioc.facade, message_id))

        # Add support to open draft if no envelope

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
                }, {
                    'viewclass': 'MDMenuItem',
                    'text': 'Trash it',
                    'callback': self.ddm_trash,
                }
            ],
            width_mult=3).open(anchor)

    def ddm_reply(self, arg):
        writer = WriteMessage()
        writer.load(self._app, self._sender, self._msg)
        writer.open()
        self.dismiss()

    def ddm_forward(self, arg):
        print(arg)

    def ddm_compose(self, arg):
        writer = WriteMessage()
        writer.load(self._app, self._sender)
        writer.open()
        self.dismiss()

    def ddm_share(self, arg):
        print(arg)

    def ddm_report(self, arg):
        print(arg)

    def ddm_trash(self, arg):
        print(arg)


class WriteMessage(BaseDialog):
    id = ''
    title = 'Compose message'
    recipient = StringProperty()
    subject = StringProperty()
    body = StringProperty()

    def load(self, app, recipient: Portfolio, reply: Mail=None):
        """Prepare the message composer dialog box."""
        self._app = app
        self._recipient = recipient
        self._builder = MessagePolicy.mail(app.ioc.facade.portfolio, recipient)
        self._reply = reply

        self.recipient = '[size=14sp][b]' + PrintPolicy.title(recipient) + '[/b][/size]'  # noqa E501
        if reply:
            self.subject = 'Reply to: ' + reply.subject if (
                reply.subject) else str(reply.id)

    def send(self):
        """Compile and send message from dialog data."""
        mail = self._app.ioc.facade.mail
        msg = self._builder.message(
            self.subject, self.body, self._reply).done()
        envelope = EnvelopePolicy.wrap(
            self._app.ioc.facade.portfolio, self._recipient, msg)
        Glue.run_async(mail.save_outbox(envelope))
        Glue.run_async(mail.save_sent(msg))
        self.dismiss()

    def save(self):
        """Compile and save message as draft from dialog data."""
        draft = self._builder.message(
            self.subject, self.body, self._reply).draft()
        Glue.run_async(self._app.ioc.facade.mail.save_draft(draft))
        self.dismiss()


class MessagesScreen(BasePanelScreen):
    def load(self):
        self.get_inbox()
        print('Load:', type(self))

    def unload(self):
        print('Unload:', type(self))

    def menu(self, name):
        """Compose button."""
        writer = WriteMessage()
        # writer.load(app, self.msg_id)
        writer.open()

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
        """Load the unopened envelopes in the inbox."""
        messages = Glue.run_async(self.app.ioc.facade.mail.load_inbox())
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('inbox')
        widget.clear_widgets()

        if not messages:
            label = EmptyList()
            label.text = EMPTY_INBOX
            widget.add_widget(label)
            return

        sv = ScrollView()
        inbox = MDList()
        sv.add_widget(inbox)
        widget.add_widget(sv)

        if messages:
            Clock.schedule_once(partial(
                self.show_inbox_item, self.app.ioc.facade.portfolio,
                messages, inbox))

    def show_inbox_item(
            self, portfolio: PrivatePortfolio,
            messages: List[Any], inbox: MDList, dt):
        """Print envelop to list kivy-async."""

        msg = messages.pop()
        if isinstance(msg[1], type(None)):
            try:
                sender = Glue.run_async(self.app.ioc.facade.load_portfolio(
                    msg[0].issuer, PGroup.VERIFIER))
                message = EnvelopePolicy.open(portfolio, sender, msg[0])
                headline = message.subject
                title = PrintPolicy.title(sender)
                source = './data/icon_72x72.png'
            except OSError:
                headline = '<Unknown>'
                title = '<Unidentified sender>'
                source = './data/anonymous.png'
            item = MsgListItem(
                text=headline,
                secondary_text=title,
            )
            item.msg_id = msg[0].id
            item.add_widget(DummyPhoto(source=source))
            inbox.add_widget(item)
        else:
            print(msg)

        if messages:
            Clock.schedule_once(partial(
                self.show_inbox_item, portfolio, messages, inbox))

    def get_outbox(self):
        messages = Glue.run_async(self.app.ioc.facade.mail.load_outbox())
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('outbox')
        widget.clear_widgets()

        if not messages:
            label = EmptyList()
            label.text = EMPTY_OUTBOX
            widget.add_widget(label)
            return

        sv = ScrollView()
        outbox = MDList()
        sv.add_widget(outbox)
        widget.add_widget(sv)

        if messages:
            Clock.schedule_once(partial(
                self.show_outbox_item, self.app.ioc.facade.portfolio,
                messages, outbox))

    def show_outbox_item(
            self, portfolio: PrivatePortfolio,
            messages: List[Any], outbox: MDList, dt):
        """Print envelop to list kivy-async."""

        msg = messages.pop()
        if isinstance(msg[1], type(None)):
            try:
                sender = Glue.run_async(self.app.ioc.facade.load_portfolio(
                    msg[0].owner, PGroup.VERIFIER))
                headline = str(msg[0].id)
                title = PrintPolicy.title(sender)
                source = './data/icon_72x72.png'
            except OSError:
                headline = '<Unknown>'
                title = '<Unidentified sender>'
                source = './data/anonymous.png'
            item = MsgListItem(
                text=headline,
                secondary_text=title,
            )
            item.msg_id = msg[0].id
            item.add_widget(DummyPhoto(source=source))
            outbox.add_widget(item)
        else:
            print(msg)

        if messages:
            Clock.schedule_once(partial(
                self.show_outbox_item, portfolio, messages, outbox))

    def get_drafts(self):
        messages = Glue.run_async(self.app.ioc.facade.mail.load_drafts())
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('drafts')
        widget.clear_widgets()

        if not messages:
            label = EmptyList()
            label.text = EMPTY_DRAFTS
            widget.add_widget(label)
            return

        sv = ScrollView()
        drafts = MDList()
        sv.add_widget(drafts)
        widget.add_widget(sv)

        if messages:
            Clock.schedule_once(partial(
                self.show_drafts_item, self.app.ioc.facade.portfolio,
                messages, drafts))

    def show_drafts_item(
            self, portfolio: PrivatePortfolio,
            messages: List[Any], drafts: MDList, dt):
        """Print envelop to list kivy-async."""

        msg = messages.pop()
        if isinstance(msg[1], type(None)):
            try:
                sender = Glue.run_async(self.app.ioc.facade.load_portfolio(
                    msg[0].issuer, PGroup.VERIFIER))
                headline = msg[0].subject if msg[0].subject else ''
                title = PrintPolicy.title(sender)
                source = './data/icon_72x72.png'
            except OSError:
                headline = '<Unknown>'
                title = '<Unidentified sender>'
                source = './data/anonymous.png'
            item = MsgListItem(
                text=headline,
                secondary_text=title,
            )
            item.msg_id = msg[0].id
            item.add_widget(DummyPhoto(source=source))
            drafts.add_widget(item)
        else:
            print('MESSAGE:', msg[1])

        if messages:
            Clock.schedule_once(partial(
                self.show_drafts_item, portfolio, messages, drafts))

    def get_read(self):
        messages = Glue.run_async(self.app.ioc.facade.mail.load_read())
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('read')
        widget.clear_widgets()

        if not messages:
            label = EmptyList()
            label.text = EMPTY_READ
            widget.add_widget(label)
            return

        sv = ScrollView()
        read = MDList()
        sv.add_widget(read)
        widget.add_widget(sv)

        if messages:
            Clock.schedule_once(partial(
                self.show_read_item, self.app.ioc.facade.portfolio,
                messages, read))

    def show_read_item(
            self, portfolio: PrivatePortfolio,
            messages: List[Any], inbox: MDList, dt):
        """Print envelop to list kivy-async."""

        msg = messages.pop()
        if isinstance(msg[1], type(None)):
            try:
                sender = Glue.run_async(self.app.ioc.facade.load_portfolio(
                    msg[0].issuer, PGroup.VERIFIER))
                headline = msg[0].subject
                title = PrintPolicy.title(sender)
                source = './data/icon_72x72.png'
            except OSError:
                headline = '<Unknown>'
                title = '<Unidentified sender>'
                source = './data/anonymous.png'
            item = MsgListItem(
                text=headline,
                secondary_text=title,
            )
            item.msg_id = msg[0].id
            item.add_widget(DummyPhoto(source=source))
            inbox.add_widget(item)
        else:
            print(msg)

        if messages:
            Clock.schedule_once(partial(
                self.show_read_item, portfolio, messages, inbox))

    def get_trash(self):
        messages = Glue.run_async(self.app.ioc.facade.mail.load_trash())
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('trash')
        widget.clear_widgets()

        if not messages:
            label = EmptyList()
            label.text = EMPTY_TRASH
            widget.add_widget(label)
            return

        sv = ScrollView()
        trash = MDList()
        sv.add_widget(trash)
        widget.add_widget(sv)

        if messages:
            Clock.schedule_once(partial(
                self.show_trash_item, self.app.ioc.facade.portfolio,
                messages, trash))

    def show_trash_item(
            self, portfolio: PrivatePortfolio,
            messages: List[Any], trash: MDList, dt):
        """Print envelop to list kivy-async."""

        msg = messages.pop()
        if isinstance(msg[1], type(None)):
            try:
                sender = Glue.run_async(self.app.ioc.facade.load_portfolio(
                    msg[0].issuer, PGroup.VERIFIER))
                headline = msg[0].subject
                title = PrintPolicy.title(sender)
                source = './data/icon_72x72.png'
            except OSError:
                headline = '<Unknown>'
                title = '<Unidentified sender>'
                source = './data/anonymous.png'
            item = MsgListItem(
                text=headline,
                secondary_text=title,
            )
            item.msg_id = msg[0].id
            item.add_widget(DummyPhoto(source=source))
            trash.add_widget(item)
        else:
            print(msg)

        if messages:
            Clock.schedule_once(partial(
                self.show_trash_item, portfolio, messages, trash))
