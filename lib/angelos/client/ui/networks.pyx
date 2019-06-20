# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import uuid
import logging
from typing import Any

from kivy.lang import Builder
from kivy.clock import Clock
from kivy.properties import ObjectProperty
from kivy.uix.image import AsyncImage

from kivymd.list import (
    OneLineAvatarIconListItem, ILeftBody, IRightBodyTouch, BaseListItem)
from kivymd.button import MDIconButton

from ...archive.helper import Glue
from .common import BasePanelScreen, EmptyList

from ...policy import PrivatePortfolio, PGroup, PrintPolicy


Builder.load_string("""
<NetworksScreen@BasePanelScreen>:
    name: 'networks'
    title: 'Networks'
    on_pre_enter: self.load()
    on_leave: self.unload()
    right_action_items:
        [['reload', lambda x: app.index_networks()]]
""")  # noqa E501

EMPTY_NETWORKS = """The network list is empty!\n[size=14sp][i]Index networks by\ntapping reload.[/i][/size]"""  # noqa E501


class DummyPhoto(ILeftBody, AsyncImage):
        pass


class RightIconButton(IRightBodyTouch, MDIconButton):
    def on_release(self):
        """Make current network prefered."""
        # network_id = self.parent.parent.network_id


class NetworkListItem(OneLineAvatarIconListItem):
    network_id = ObjectProperty()

    def on_release(self):
        """"""
        def later(dt):
            try:
                result = future.result()
                print(type(result), result)
            except Exception as e:
                logging.info('Failed to connect')
                logging.exception(e)

        try:
            app = self.parent.parent.parent.parent.parent.app
            future = app.connect_network(self.network_id)
            Clock.schedule_once(later, 5)
        except Exception as e:
            logging.info('Failed to connect')
            logging.exception(e)


class NetworksScreen(BasePanelScreen):
    widget = None

    def load(self):
        """Load the unopened envelopes in the inbox."""
        panel = self.ids['panel']
        networks = Glue.run_async(self.app.ioc.facade.settings.networks())

        if not networks:
            self.widget = EmptyList(text=EMPTY_NETWORKS)
            panel.add_widget(self.widget)
            return
        else:
            self.widget = self.list_loader(
                networks, panel, self.show_network_item)

    def show_network_item(
            self,
            portfolio: PrivatePortfolio, listitem: Any) -> BaseListItem:
        """Print envelop to list kivy-async."""
        try:
            network = Glue.run_async(self.app.ioc.facade.load_portfolio(
                uuid.UUID(listitem[0]), PGroup.SHARE_MED_COMMUNITY))
            title = PrintPolicy.title(network)
            if listitem[1] is True:
                source = './data/bulb.png'
            else:
                source = './data/icon_72x72.png'
        except OSError:
            title = '<Unidentified network>'
            source = './data/anonymous.png'

        item = NetworkListItem(text=title)
        item.network_id = network.entity.id
        item.add_widget(DummyPhoto(source=source))
        item.add_widget(RightIconButton(icon='check-network'))
        return item
