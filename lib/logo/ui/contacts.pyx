# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring"""
from kivy.lang import Builder
from kivy.clock import Clock
from kivy.properties import StringProperty
from kivy.uix.scrollview import ScrollView
from kivy.uix.image import AsyncImage
from kivymd.uix.dialog import BaseDialog
from kivymd.uix.label import MDLabel
from kivymd.uix.selectioncontrol import MDCheckbox
from kivymd.uix.list import (
    MDList, OneLineAvatarIconListItem, ILeftBody, IRightBodyTouch)
from kivymd.uix.bottomsheet import MDListBottomSheet


from typing import List, Any
from functools import partial

from .common import BasePanelScreen

from libangelos.archive.helper import Glue
from libangelos.policy.print import PrintPolicy
from libangelos.policy.portfolio import PrivatePortfolio, PGroup
from libangelos.document.messages import Mail
from libangelos.policy.message import EnvelopePolicy, MessagePolicy
from libangelos.policy.portfolio import Portfolio


Builder.load_string("""
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

EMPTY_ALL_CONTACTS = """The contacts are empty!"""


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

    def show_menu(self, app):
        menu = MDListBottomSheet()
        menu.add_item(
            "New message",
            lambda x: self.bs_compose(app),
            icon="email-outline",
        )
        menu.add_item(
            "Profile",
            lambda x: None,
            icon="face-profile",
        )
        menu.add_item(
            "Portfolio",
            lambda x: None,
            icon="briefcase-check",
        )
        menu.add_item(
            "Friend",
            lambda x: None,
            icon="heart",
        )
        menu.add_item(
            "Favorite",
            lambda x: None,
            icon="star",
        )
        menu.add_item(
            "Block",
            lambda x: None,
            icon="block-helper",
        )
        menu.open()

    def bs_compose(self, app):
        sender = Glue.run_async(app.ioc.facade.load_portfolio(
            self.entity_id, PGroup.VERIFIER))
        writer = WriteMessage()
        writer.load(app, sender)
        writer.open()


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
        entities = Glue.run_async(self.app.ioc.facade.contact.load_all())
        widget = self.ids['bottom_nav'].ids.tab_manager.get_screen('all')
        widget.clear_widgets()

        if not entities:
            label = EmptyList()
            label.text = EMPTY_ALL_CONTACTS
            widget.add_widget(label)
            return

        sv = ScrollView()
        all = MDList()
        sv.add_widget(all)
        widget.add_widget(sv)

        if entities:
            Clock.schedule_once(partial(
                self.show_contact_item, self.app.ioc.facade.portfolio,
                entities, all))

    def show_contact_item(
            self, portfolio: PrivatePortfolio,
            entities: List[Any], list_widget: MDList, dt):
        """Print contact to list kivy-async."""

        entity = entities.pop()
        if isinstance(entity[1], type(None)) and (
                portfolio.entity.id != entity[0].id):
            try:
                title = PrintPolicy.entity_title(entity[0])
                source = './data/icon_72x72.png'
            except OSError:
                title = '<Unidentified sender>'
                source = './data/anonymous.png'
            item = ContactListItem(
                text=title,
            )
            item.entity_id = entity[0].id
            item.add_widget(DummyPhoto(source=source))
            list_widget.add_widget(item)
        else:
            print(entity)

        if entities:
            Clock.schedule_once(partial(
                self.show_contact_item, portfolio, entities, list_widget))


Builder.load_string("""
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
""")  # noqa E501


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
