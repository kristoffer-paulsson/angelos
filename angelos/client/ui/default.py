from kivy.lang import Builder
from kivy.metrics import dp
from kivy.uix.image import Image
from kivy.uix.screenmanager import Screen

from kivy.garden.qrcode import QRCodeWidget

from kivymd.list import (
    MDList, TwoLineIconListItem, OneLineAvatarIconListItem,
    OneLineIconListItem, ILeftBody, ILeftBodyTouch, IRightBodyTouch)
from kivymd.selectioncontrols import MDCheckbox, MDSwitch
from kivymd.bottomsheet import MDListBottomSheet
from kivymd.button import MDIconButton
from kivymd.dialog import MDDialog
# from kivymd.label import MDLabel


Builder.load_string('''
#:import NavigationLayout kivymd.navigationdrawer.NavigationLayout
#:import MDNavigationDrawer kivymd.navigationdrawer.MDNavigationDrawer

#:import OneLineListItem kivymd.list.OneLineListItem
#:import TwoLineListItem kivymd.list.TwoLineListItem
#:import ThreeLineListItem kivymd.list.ThreeLineListItem
#:import OneLineAvatarListItem kivymd.list.OneLineAvatarListItem
#:import OneLineIconListItem kivymd.list.OneLineIconListItem
#:import OneLineAvatarIconListItem kivymd.list.OneLineAvatarIconListItem
#:import MDBottomNavigation kivymd.tabs.MDBottomNavigation
#:import MDBottomNavigationItem kivymd.tabs.MDBottomNavigationItem

<DefaultNavigation>:
    name: 'main'
    on_pre_enter: profile.load(app)
    NavigationLayout:
        id: nav_layout
        MDNavigationDrawer:
            id: nav_drawer
            NavigationDrawerToolbar:
                title: "Navigation Drawer"
            NavigationDrawerIconButton:
                icon: 'account'
                text: "Profile"
                on_release: scr_mngr.current = 'profile'
            NavigationDrawerIconButton:
                icon: 'contact-mail'
                text: "Contacts"
                badge_text: "243"
                on_release: scr_mngr.current = 'contacts'
            NavigationDrawerIconButton:
                icon: 'email-secure'
                text: "Messages"
                badge_text: "7"
                on_release: scr_mngr.current = 'messages'
            NavigationDrawerIconButton:
                icon: 'library-books'
                text: "Files"
                on_release: scr_mngr.current = 'files'
            NavigationDrawerIconButton:
                icon: 'church'
                text: "Networks"
                on_release: scr_mngr.current = 'networks'
            NavigationDrawerIconButton:
                icon: 'settings-box'
                text: "Settings"
                on_release: scr_mngr.current = 'settings'
        BoxLayout:
            orientation: 'vertical'
            Toolbar:
                id: toolbar
                title: 'Logo - messenger'
                md_bg_color: app.theme_cls.primary_color
                background_palette: 'Primary'
                background_hue: '500'
                left_action_items: [ \
                ['menu', lambda x: nav_layout.toggle_nav_drawer()]]
                right_action_items: []
            ScreenManager:
                id: scr_mngr
                Screen:
                    name: 'profile'
                    on_pre_enter: profile.load(app)
                    ScrollView:
                        do_scroll_x: False
                        Profile:
                            id: profile
                            ThreeLineIconListItem:
                                text: "Berzeliigatan 15" + '\\n' + "412 53 GÖTEBORG"
                                secondary_text: "Address"
                                IconLeftSampleWidget:
                                    icon: 'map-marker'
                            TwoLineIconListItem:
                                text: "herbert.gustafsson@example.com"
                                secondary_text: "Email"
                                IconLeftSampleWidget:
                                    icon: 'email-outline'
                            TwoLineIconListItem:
                                text: "+46 (0)73-45 67 890"
                                secondary_text: "Cellphone"
                                IconLeftSampleWidget:
                                    icon: 'cellphone'
                            TwoLineIconListItem:
                                text: "+46 (0)31-23 45 67"
                                secondary_text: 'Landline'
                                IconLeftSampleWidget:
                                    icon: 'phone'
                            TwoLineIconListItem:
                                text: "@herbert_gustafsson"
                                secondary_text: 'Twitter'
                                IconLeftSampleWidget:
                                    icon: 'robot'
                            TwoLineIconListItem:
                                text: "Swedish, English"
                                secondary_text: "Languages"
                                IconLeftSampleWidget:
                                    icon: 'earth'
                Screen:
                    name: 'contacts'
                    MDBottomNavigation:
                        id: contacts_navigation
                        MDBottomNavigationItem:
                            name: 'favorites'
                            text: "Favorites"
                            icon: "star"
                            ScrollView:
                                do_scroll_x: False
                                ContactList:
                                    id: contacts
                                    ThreeLineAvatarIconListItem:
                                        text: "Albin Hägglund"
                                        secondary_text: "Fotledsvägen 3" + '\\n' + "182 57 Danderyd"
                                        on_touch_move: print(self.text + " move")
                                        on_release: contacts.contact_action_bs()
                                        AvatarSampleWidget:
                                        IconRightSampleWidget:
                                    ThreeLineAvatarIconListItem:
                                        text: "Benjamin Dalin"
                                        secondary_text: "Aftonstigen 2" + '\\n' + "573 73 Sunhultsbrunn"
                                        AvatarSampleWidget:
                                        IconRightSampleWidget:
                                    ThreeLineAvatarIconListItem:
                                        text: "Ida Winblad"
                                        secondary_text: "Omvägen 15" + '\\n' + "953 33 Haparanda"
                                        AvatarSampleWidget:
                                        IconRightSampleWidget:
                                    ThreeLineAvatarIconListItem:
                                        text: "Maj-Britt Ekblad"
                                        secondary_text: "Optand 257" + '\\n' + "831 92 Östersund"
                                        AvatarSampleWidget:
                                        IconRightSampleWidget:
                                    ThreeLineAvatarIconListItem:
                                        text: "Greta Hägg"
                                        secondary_text: "Hovängsvägen 2" + '\\n' + "632 29 Eskilstuna"
                                        AvatarSampleWidget:
                                        IconRightSampleWidget:
                                    ThreeLineAvatarIconListItem:
                                        text: "Gun Lindgren"
                                        secondary_text: "Raabens väg 4" + '\\n' + "593 74 Gunnebo"
                                        AvatarSampleWidget:
                                        IconRightSampleWidget:
                                    ThreeLineAvatarIconListItem:
                                        text: "Emanuel Sandberg"
                                        secondary_text: "Luveryd Slättaberg 4" + '\\n' + "331 77 Rydaholm"
                                        AvatarSampleWidget:
                                        IconRightSampleWidget:
                                    ThreeLineAvatarIconListItem:
                                        text: "Hannes Sjögren"
                                        secondary_text: "Oxås 3" + '\\n' + "333 92 Broaryd"
                                        AvatarSampleWidget:
                                        IconRightSampleWidget:
                                    ThreeLineAvatarIconListItem:
                                        text: "Gösta Blom"
                                        secondary_text: "Gitarrvägen 11" + '\\n' + "352 45 Växjö"
                                        AvatarSampleWidget:
                                        IconRightSampleWidget:
                                    ThreeLineAvatarIconListItem:
                                        text: "Tilde Bergqvist"
                                        secondary_text: "Tovhultstorpet 1" + '\\n' + "333 74 Bredaryd"
                                        AvatarSampleWidget:
                                        IconRightSampleWidget:
                        MDBottomNavigationItem:
                            name: 'friends'
                            text: "Friends"
                            icon: "heart"
                            MDLabel:
                                font_style: 'Body1'
                                theme_text_color: 'Primary'
                                text: "Friends list"
                                halign: 'center'
                        MDBottomNavigationItem:
                            name: 'family'
                            text: "Family"
                            icon: "church"
                            MDLabel:
                                font_style: 'Body1'
                                theme_text_color: 'Primary'
                                text: "Family list"
                                halign: 'center'
                        MDBottomNavigationItem:
                            name: 'blocked'
                            text: "Blocked"
                            icon: "alert-octagon"
                            MDLabel:
                                font_style: 'Body1'
                                theme_text_color: 'Primary'
                                text: "Blocked list"
                                halign: 'center'
                        MDBottomNavigationItem:
                            name: 'all'
                            text: "All"
                            icon: "book-open-variant"
                            MDLabel:
                                font_style: 'Body1'
                                theme_text_color: 'Primary'
                                text: "All list"
                                halign: 'center'
                Screen:
                    name: 'messages'
                    BoxLayout:
                        size_hint: None, None
                        size: '200dp', '50dp'
                        padding: '12dp'
                        pos_hint: {'center_x': 0.75, 'center_y': 0.8}
                        MDLabel:
                            font_style: 'Body1'
                            theme_text_color: 'Primary'
                            text: "Page 3"
                            size_hint_x:None
                            width: '56dp'
                Screen:
                    name: 'files'
                    BoxLayout:
                        size_hint: None, None
                        size: '200dp', '50dp'
                        padding: '12dp'
                        pos_hint: {'center_x': 0.75, 'center_y': 0.8}
                        MDLabel:
                            font_style: 'Body1'
                            theme_text_color: 'Primary'
                            text: "Page 3"
                            size_hint_x:None
                            width: '56dp'
                Screen:
                    name: 'networks'
                    BoxLayout:
                        size_hint: None, None
                        size: '200dp', '50dp'
                        padding: '12dp'
                        pos_hint: {'center_x': 0.75, 'center_y': 0.8}
                        MDLabel:
                            font_style: 'Body1'
                            theme_text_color: 'Primary'
                            text: "Page 3"
                            size_hint_x:None
                            width: '56dp'
                Screen:
                    name: 'settings'
                    BoxLayout:
                        size_hint: None, None
                        size: '200dp', '50dp'
                        padding: '12dp'
                        pos_hint: {'center_x': 0.75, 'center_y': 0.8}
                        MDLabel:
                            font_style: 'Body1'
                            theme_text_color: 'Primary'
                            text: "Page 3"
                            size_hint_x:None
                            width: '56dp'
<Profile>
<ContactList>
''')  # noqa E501


class DefaultNavigation(Screen):
    pass


class ProfileToggle(OneLineAvatarIconListItem):
    pass


class ContactList(MDList):
    def contact_action_bs(self):
        bs = MDListBottomSheet()
        bs.add_item("Send", lambda x: x, icon='email')
        bs.add_item("Messages", lambda x: x, icon='email-open')
        bs.add_item("Groups", lambda x: x, icon='tag-faces')
        bs.add_item("Certify", lambda x: x, icon='certificate')
        bs.add_item("Documents", lambda x: x, icon='file')
        bs.add_item("Block", lambda x: x, icon='alert-octagon')
        bs.open()


class Profile(MDList):
    edit = False

    def load(self, app):
        self.clear_widgets()
        eid = app.ioc.facade.id
        entity = app.ioc.facade.entity

        # Unlock
        lock_li = OneLineAvatarIconListItem(text='Unlock edit mode')
        lock_li.add_widget(IconLeftWidget(icon='lock-open'))
        lock_li.add_widget(IconRightSwitch(
            on_press=lambda x: self.toggle(x.active)))
        self.add_widget(lock_li, 0)

        # Id
        id_li = OneLineIconListItem(
            text=eid, on_press=lambda x: self.scan_dialog(eid, app))
        id_li.add_widget(IconLeftWidget(icon='information-outline'))
        self.add_widget(id_li, 2)

        # Gendeer
        gender_li = TwoLineIconListItem(
            text=entity.gender,
            secondary_text='Gender')
        gender_li.add_widget(IconLeftWidget(icon='human'))
        self.add_widget(gender_li, 3)

        # Date
        date_li = TwoLineIconListItem(
            text=entity.born,
            secondary_text='Date of birth')
        date_li.add_widget(IconLeftWidget(icon='calendar-blank'))
        self.add_widget(date_li, 4)

        # Address
        # Email
        # Cellphone
        # Landline
        # Social
        # Languages

        # Name
        name_li = TwoLineIconListItem(
            text=entity.given_name + ' ' + entity.family_name,
            secondary_text='Full name')
        name_li.add_widget(IconLeftWidget(icon='face-profile'))
        self.add_widget(name_li, 1000)

    def toggle(self, t):
        self.edit = not t
        print('Toggle', self.edit)

    def scan_dialog(self, id, app):
        f = app.ioc.facade
        doc = f.find_person(id) + f.find_keys(id)
        print(doc)
        dialog = MDDialog(
            title='Entity QR', content=QRCodeWidget(
                data=doc, height=dp(500),
                pos_hint={'center_x': .5, 'center_y': .5},
                size_hint=(1, None)))
        dialog.add_action_button(
            'Dismiss', action=lambda *x: dialog.dismiss())
        dialog.open()


class IconLeftWidget(ILeftBodyTouch, MDIconButton):
    pass


class IconRightSwitch(IRightBodyTouch, MDSwitch):
    pass


class IconRightCheckbox(IRightBodyTouch, MDCheckbox):
    pass


#############################


class AvatarSampleWidget(ILeftBody, Image):
    pass


class IconLeftSampleWidget(ILeftBodyTouch, MDIconButton):
    pass


class IconRightSampleWidget(IRightBodyTouch, MDCheckbox):
    pass


class IconRightSampleSwitch(IRightBodyTouch, MDSwitch):
    pass
