# cython: language_level=3
import math

from kivy.lang import Builder
from kivy.metrics import dp
from kivy.uix.image import Image
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.screenmanager import Screen

from kivy.graphics.fbo import Fbo
from kivy.graphics import ClearColor, ClearBuffers, Scale, Translate

from kivy.garden.qrcode import QRCodeWidget

from kivymd.list import (
    MDList, TwoLineIconListItem, OneLineAvatarIconListItem,
    ThreeLineIconListItem, OneLineIconListItem, ILeftBody, ILeftBodyTouch,
    IRightBodyTouch, BaseListItem, ContainerSupport)
from kivymd.selectioncontrols import MDCheckbox, MDSwitch
from kivymd.bottomsheet import MDListBottomSheet
from kivymd.button import MDIconButton
from kivymd.dialog import MDDialog
from kivymd.menus import MDDropdownMenu
# from kivymd.label import MDLabel

from ...const import Const
from ..events import Messages


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
            ScreenManager:
                id: scr_mngr
                Screen:
                    name: 'profile'
                    on_pre_enter: profile.load(app)
                    BoxLayout:
                        orientation: 'vertical'
                        Toolbar:
                            title: 'Logo - Profile'
                            md_bg_color: app.theme_cls.primary_color
                            left_action_items: [ \
                            ['menu', lambda x: nav_layout.toggle_nav_drawer()]]
                            right_action_items: [ \
                            ['dots-vertical', lambda x: profile.open_menu(self.ids.right_actions)]]
                        ScrollView:
                            do_scroll_x: False
                            Profile:
                                id: profile
                                TwoLineIconListItem:
                                    text: "Swedish, English"
                                    secondary_text: "Languages"
                                    IconLeftSampleWidget:
                                        icon: 'earth'
                Screen:
                    name: 'contacts'
                    BoxLayout:
                        orientation: 'vertical'
                        Toolbar:
                            title: 'Logo - Contacts'
                            md_bg_color: app.theme_cls.primary_color
                            left_action_items: [ \
                            ['menu', lambda x: nav_layout.toggle_nav_drawer()]]
                            right_action_items: []
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
                        orientation: 'vertical'
                        Toolbar:
                            title: 'Logo - Messages'
                            md_bg_color: app.theme_cls.primary_color
                            left_action_items: [ \
                            ['menu', lambda x: nav_layout.toggle_nav_drawer()]]
                            right_action_items: []
                        MDLabel:
                            font_style: 'Body1'
                            theme_text_color: 'Primary'
                            text: "Page 3"
                            size_hint_x:None
                            width: '56dp'
                Screen:
                    name: 'files'
                    BoxLayout:
                        orientation: 'vertical'
                        Toolbar:
                            title: 'Logo - Files'
                            md_bg_color: app.theme_cls.primary_color
                            left_action_items: [ \
                            ['menu', lambda x: nav_layout.toggle_nav_drawer()]]
                            right_action_items: []
                        MDLabel:
                            font_style: 'Body1'
                            theme_text_color: 'Primary'
                            text: "Page 4"
                            size_hint_x:None
                            width: '56dp'
                Screen:
                    name: 'networks'
                    BoxLayout:
                        orientation: 'vertical'
                        Toolbar:
                            title: 'Logo - Churches'
                            md_bg_color: app.theme_cls.primary_color
                            left_action_items: [ \
                            ['menu', lambda x: nav_layout.toggle_nav_drawer()]]
                            right_action_items: []
                        MDLabel:
                            font_style: 'Body1'
                            theme_text_color: 'Primary'
                            text: "Page 5"
                            size_hint_x:None
                            width: '56dp'
                Screen:
                    name: 'settings'
                    BoxLayout:
                        orientation: 'vertical'
                        Toolbar:
                            title: 'Logo - Settings'
                            md_bg_color: app.theme_cls.primary_color
                            left_action_items: [ \
                            ['menu', lambda x: nav_layout.toggle_nav_drawer()]]
                            right_action_items: []
                        MDLabel:
                            font_style: 'Body1'
                            theme_text_color: 'Primary'
                            text: "Page 6"
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
    menu_items = []

    def load(self, app):
        self.clear_widgets()
        self.menu_items.clear()
        eid = app.ioc.facade.id
        entity = app.ioc.facade.entity
        address = app.ioc.facade.address
        email = app.ioc.facade.email
        mobile = app.ioc.facade.mobile
        phone = app.ioc.facade.phone
        social = app.ioc.facade.social

        # Unlock
        lock_li = OneLineAvatarIconListItem(text='Unlock edit mode')
        lock_li.add_widget(IconLeftWidget(icon='lock-open'))
        lock_li.add_widget(IconRightSwitch(
            on_press=lambda x: self.toggle(x.active), active=self.edit))
        self.add_widget(lock_li, 0)

        # Id
        id_li = OneLineIconListItem(
            text=eid, on_press=lambda x: self.idqr_dialog(eid, app))
        id_li.add_widget(IconLeftWidget(icon='information-outline'))
        self.add_widget(id_li, 2)

        # Gendeer
        gender_li = TwoLineIconListItem(
            text=entity.gender.capitalize(),
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
        if isinstance(address, PersonFacade.Address):
            addr_li = ThreeLineIconListItem(
                text=address.street + ' ' + address.number + '\n' +
                address.zip + ' ' + address.city,
                secondary_text='Address',
                on_release=lambda x: AddressDialog(
                    app, self, data=app.ioc.facade.address
                    ) if self.edit else None)
            addr_li.add_widget(IconLeftWidget(icon='map-marker'))
            self.add_widget(addr_li, 5)
        else:
            self.menu_items.append({
                'viewclass': 'MDMenuItem', 'text': 'Add an address',
                'on_release': lambda: AddressDialog(app, self)})

        # Email
        if bool(email):
            mail_li = TwoLineIconListItem(
                text=email,
                secondary_text='Email',
                on_release=lambda x: EmailDialog(
                    app, self, data=app.ioc.facade.email
                    ) if self.edit else None)
            mail_li.add_widget(IconLeftWidget(icon='email-outline'))
            self.add_widget(mail_li, 6)
        else:
            self.menu_items.append({
                'viewclass': 'MDMenuItem', 'text': 'Add an email',
                'on_release': lambda: EmailDialog(app, self)})

        # Cellphone
        if bool(mobile):
            mob_li = TwoLineIconListItem(
                text=mobile,
                secondary_text='Mobile',
                on_release=lambda x: MobileDialog(
                    app, self, data=app.ioc.facade.mobile
                    ) if self.edit else None)
            mob_li.add_widget(IconLeftWidget(icon='cellphone'))
            self.add_widget(mob_li, 7)
        else:
            self.menu_items.append({
                'viewclass': 'MDMenuItem', 'text': 'Add mobile',
                'on_release': lambda: MobileDialog(app, self)})

        # Landline
        if bool(phone):
            phon_li = TwoLineIconListItem(
                text=phone,
                secondary_text='Phone',
                on_release=lambda x: PhoneDialog(
                    app, self, data=app.ioc.facade.phone
                    ) if self.edit else None)
            phon_li.add_widget(IconLeftWidget(icon='phone'))
            self.add_widget(phon_li, 8)
        else:
            self.menu_items.append({
                'viewclass': 'MDMenuItem', 'text': 'Add phone',
                'on_release': lambda: PhoneDialog(app, self)})

        # Social
        if bool(social):
            for media in social:
                soc_li = TwoLineIconListItem(
                    text=social[media].token,
                    secondary_text=social[media].media,
                    on_release=lambda x: SocialMediaDialog(
                        app, self, data=social[media]
                        ) if self.edit else None)
                soc_li.add_widget(IconLeftWidget(icon='android'))
                self.add_widget(soc_li, 300)

        self.menu_items.append({
            'viewclass': 'MDMenuItem', 'text': 'Add Social',
            'on_release': lambda: SocialMediaDialog(app, self)})

        # Languages
        self.menu_items.append({
            'viewclass': 'MDMenuItem', 'text': 'Add languages',
            'on_release': lambda: 'Implement languages dialog'})

        # Name
        name_li = TwoLineIconListItem(
            text=entity.given_name + ' ' + entity.family_name,
            secondary_text='Name',
            on_press=lambda x: CameraDialog(app, self) if self.edit else None)
        name_li.add_widget(IconLeftWidget(icon='face-profile'))
        self.add_widget(name_li, 1000)

    def toggle(self, t):
        self.edit = not t

    def idqr_dialog(self, id, app):
        f = app.ioc.facade
        doc = f.find_person(id) + f.find_keys(id)
        dialog = MDDialog(
            title=id, content=QRCodeWidget(
                data=doc, height=dp(500),
                pos_hint={'center_x': .5, 'center_y': .5},
                size_hint=(1, None)))
        dialog.add_action_button(
            'Dismiss', action=lambda *x: dialog.dismiss())
        dialog.open()

    def open_menu(self, anchor):
        MDDropdownMenu(items=self.menu_items, width_mult=4).open(anchor)


Builder.load_string('''
<AddressContent>:
    orientation: 'vertical'
    MDLabel:
        text: "You may fill in your address. If you do, please fill in the information truthfully. If you for any reason don\'t want to give certain information, you are free to leave it blank."
        font_style: 'Body1'
        theme_text_color: 'Primary'
        halign: 'left'
    MDLabel:
        text: "This information remains private to you. You have to make a wilful choice in order to share with others."
        font_style: 'Body1'
        theme_text_color: 'Error'
        halign: 'left'
    BoxLayout:
        orientation: 'horizontal'
        spacing: dp(25)
        MDTextField:
            id: street
            text: root.data.street if bool(root.data) else ''
            hint_text: "Street"
            helper_text: "Street name"
            helper_text_mode: "persistent"
            multiline: False
            size_hint: .8, None
            valign: 'top'
        MDTextField:
            id: number
            text: root.data.number if bool(root.data) else ''
            hint_text: "No.#"
            helper_text: "Number"
            helper_text_mode: "persistent"
            multiline: False
            size_hint: .2, None
            valign: 'top'
    MDTextField:
        id: address2
        text: root.data.address2 if bool(root.data) else ''
        hint_text: "Address 2"
        helper_text: "2nd address line (if applicable)"
        helper_text_mode: "persistent"
        multiline: False
        valign: 'top'
    BoxLayout:
        orientation: 'horizontal'
        spacing:  dp(25)
        MDTextField:
            id: zip
            text: root.data.zip if bool(root.data) else ''
            hint_text: "Zip"
            helper_text: "Zip code"
            helper_text_mode: "persistent"
            multiline: False
            size_hint: .4, None
            valign: 'top'
        MDTextField:
            id: city
            text: root.data.city if bool(root.data) else ''
            hint_text: "City"
            helper_text: ""
            helper_text_mode: "persistent"
            multiline: False
            size_hint: .6, None
            valign: 'top'
    BoxLayout:
        orientation: 'horizontal'
        spacing:  dp(25)
        MDTextField:
            id: state
            text: root.data.state if bool(root.data) else ''
            hint_text: "State"
            helper_text: "(if applicable)"
            helper_text_mode: "persistent"
            multiline: False
            size_hint: .3, None
            valign: 'top'
        MDTextField:
            id: country
            text: root.data.country if bool(root.data) else ''
            hint_text: "Country"
            helper_text: ""
            helper_text_mode: "persistent"
            multiline: False
            size_hint: .7, None
            valign: 'top'
    BoxLayout:
''')  # noqa E501


class AddressDialog:
    def __init__(self, app, parent, data=None):
        self.__app = app
        self.__parent = parent

        content = AddressDialog.AddressContent(
            data=data,
            height=dp(500),
            pos_hint={'center_x': .5, 'center_y': .5},
            size_hint=(1, None))

        self.__dialog = MDDialog(title='Address', content=content)
        if bool(data):
            self.__dialog.add_action_button(
                'Delete', action=lambda *x: self.delete())
        self.__dialog.add_action_button(
            'Cancel', action=lambda *x: self.__dialog.dismiss())
        self.__dialog.add_action_button(
            'Save', action=lambda *x: self.save())
        self.__dialog.open()

    def save(self):
        ids = self.__dialog.content.ids
        self.__app.ioc.facade.address = PersonFacade.Address(
            street=str(ids.street.text).strip(),
            number=str(ids.number.text).strip(),
            address2=str(ids.address2.text).strip(),
            zip=str(ids.zip.text).strip(),
            city=str(ids.city.text).strip(),
            state=str(ids.state.text).strip(),
            country=str(ids.country.text).strip()
        )
        self.__app.ioc.facade.save()
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    def delete(self):
        self.__app.ioc.facade.address = None
        self.__app.ioc.facade.save()
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    class AddressContent(BoxLayout):
        def __init__(self, data, **kwargs):
            self.data = data
            BoxLayout.__init__(self, **kwargs)


Builder.load_string('''
<EmailContent>:
    orientation: 'vertical'
    MDLabel:
        text: "You may fill in your Email address. If you do, please fill in the information truthfully. If you for any reason don\'t want to give certain information, you are free to leave it blank."
        font_style: 'Body1'
        theme_text_color: 'Primary'
        halign: 'left'
    MDLabel:
        text: "This information remains private to you. You have to make a wilful choice in order to share with others."
        font_style: 'Body1'
        theme_text_color: 'Error'
        halign: 'left'
    MDTextField:
        id: email
        text: root.data if bool(root.data) else ''
        hint_text: "Email"
        helper_text: "Valid email address"
        helper_text_mode: "persistent"
        multiline: False
        color_mode: 'custom'
        valign: 'top'
    BoxLayout:
''')  # noqa E501


class EmailDialog:
    def __init__(self, app, parent, data=None):
        self.__app = app
        self.__parent = parent

        content = EmailDialog.EmailContent(
            data=data,
            height=dp(500),
            pos_hint={'center_x': .5, 'center_y': .5},
            size_hint=(1, None))

        self.__dialog = MDDialog(title='Email', content=content)
        if bool(data):
            self.__dialog.add_action_button(
                'Delete', action=lambda *x: self.delete())
        self.__dialog.add_action_button(
            'Cancel', action=lambda *x: self.__dialog.dismiss())
        self.__dialog.add_action_button(
            'Save', action=lambda *x: self.save())
        self.__dialog.open()

    def save(self):
        ids = self.__dialog.content.ids
        self.__app.ioc.facade.email = str(ids.email.text).strip()
        self.__app.ioc.facade.save()
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    def delete(self):
        self.__app.ioc.facade.email = None
        self.__app.ioc.facade.save()
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    class EmailContent(BoxLayout):
        def __init__(self, data, **kwargs):
            self.data = data
            BoxLayout.__init__(self, **kwargs)


Builder.load_string('''
<MobileContent>:
    orientation: 'vertical'
    MDLabel:
        text: "You may fill in your Mobile number. If you do, please fill in the information truthfully. If you for any reason don\'t want to give certain information, you are free to leave it blank."
        font_style: 'Body1'
        theme_text_color: 'Primary'
        halign: 'left'
    MDLabel:
        text: "This information remains private to you. You have to make a wilful choice in order to share with others."
        font_style: 'Body1'
        theme_text_color: 'Error'
        halign: 'left'
    MDTextField:
        id: mobile
        text: root.data if bool(root.data) else ''
        hint_text: "Mobile"
        helper_text: "Valid mobile number"
        helper_text_mode: "persistent"
        multiline: False
        color_mode: 'custom'
        valign: 'top'
    BoxLayout:
''')  # noqa E501


class MobileDialog:
    def __init__(self, app, parent, data=None):
        self.__app = app
        self.__parent = parent

        content = MobileDialog.MobileContent(
            data=data,
            height=dp(500),
            pos_hint={'center_x': .5, 'center_y': .5},
            size_hint=(1, None))

        self.__dialog = MDDialog(title='Mobile', content=content)
        if bool(data):
            self.__dialog.add_action_button(
                'Delete', action=lambda *x: self.delete())
        self.__dialog.add_action_button(
            'Cancel', action=lambda *x: self.__dialog.dismiss())
        self.__dialog.add_action_button(
            'Save', action=lambda *x: self.save())
        self.__dialog.open()

    def save(self):
        ids = self.__dialog.content.ids
        self.__app.ioc.facade.mobile = str(ids.mobile.text).strip()
        self.__app.ioc.facade.save()
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    def delete(self):
        self.__app.ioc.facade.mobile = None
        self.__app.ioc.facade.save()
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    class MobileContent(BoxLayout):
        def __init__(self, data, **kwargs):
            self.data = data
            BoxLayout.__init__(self, **kwargs)


Builder.load_string('''
<PhoneContent>:
    orientation: 'vertical'
    MDLabel:
        text: "You may fill in your Phone number. If you do, please fill in the information truthfully. If you for any reason don\'t want to give certain information, you are free to leave it blank."
        font_style: 'Body1'
        theme_text_color: 'Primary'
        halign: 'left'
    MDLabel:
        text: "This information remains private to you. You have to make a wilful choice in order to share with others."
        font_style: 'Body1'
        theme_text_color: 'Error'
        halign: 'left'
    MDTextField:
        id: phone
        text: root.data if bool(root.data) else ''
        hint_text: "Phone"
        helper_text: "Valid phone number"
        helper_text_mode: "persistent"
        multiline: False
        color_mode: 'custom'
        valign: 'top'
    BoxLayout:
''')  # noqa E501


class PhoneDialog:
    def __init__(self, app, parent, data=None):
        self.__app = app
        self.__parent = parent

        content = PhoneDialog.PhoneContent(
            data=data,
            height=dp(500),
            pos_hint={'center_x': .5, 'center_y': .5},
            size_hint=(1, None))

        self.__dialog = MDDialog(title='Phone', content=content)
        if bool(data):
            self.__dialog.add_action_button(
                'Delete', action=lambda *x: self.delete())
        self.__dialog.add_action_button(
            'Cancel', action=lambda *x: self.__dialog.dismiss())
        self.__dialog.add_action_button(
            'Save', action=lambda *x: self.save())
        self.__dialog.open()

    def save(self):
        ids = self.__dialog.content.ids
        self.__app.ioc.facade.phone = str(ids.phone.text).strip()
        self.__app.ioc.facade.save()
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    def delete(self):
        self.__app.ioc.facade.phone = None
        self.__app.ioc.facade.save()
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    class PhoneContent(BoxLayout):
        def __init__(self, data, **kwargs):
            self.data = data
            BoxLayout.__init__(self, **kwargs)


Builder.load_string('''
<SocialMediaContent>:
    orientation: 'vertical'
    MDLabel:
        text: "You may fill in your Social. If you do, please fill in the information truthfully. If you for any reason don\'t want to give certain information, you are free to leave it blank."
        font_style: 'Body1'
        theme_text_color: 'Primary'
        halign: 'left'
    MDLabel:
        text: "This information remains private to you. You have to make a wilful choice in order to share with others."
        font_style: 'Body1'
        theme_text_color: 'Error'
        halign: 'left'
    MDTextField:
        id: token
        text: root.data.token if bool(root.data) else ''
        hint_text: "Token"
        helper_text: "Token/username/profile page"
        helper_text_mode: "persistent"
        multiline: False
        color_mode: 'custom'
        valign: 'top'
    MDTextField:
        id: media
        text: root.data.media if bool(root.data) else ''
        hint_text: "Social media"
        helper_text: "Social media name"
        helper_text_mode: "persistent"
        multiline: False
        color_mode: 'custom'
        valign: 'top'
    BoxLayout:
''')  # noqa E501


class SocialMediaDialog:
    def __init__(self, app, parent, data=None):
        self.__app = app
        self.__parent = parent

        content = SocialMediaDialog.SocialMediaContent(
            data=data,
            height=dp(500),
            pos_hint={'center_x': .5, 'center_y': .5},
            size_hint=(1, None))

        self.__dialog = MDDialog(title='Social media', content=content)
        if bool(data):
            self.__dialog.add_action_button(
                'Delete', action=lambda *x: self.delete())
        self.__dialog.add_action_button(
            'Cancel', action=lambda *x: self.__dialog.dismiss())
        self.__dialog.add_action_button(
            'Save', action=lambda *x: self.save())
        self.__dialog.open()

    def save(self):
        ids = self.__dialog.content.ids
        media = PersonFacade.Social(
            token=str(ids.token.text).strip(),
            media=list(filter(
                None, ids.media.text.strip().split(' ')))[0].capitalize())
        self.__app.ioc.facade.del_social(media)
        self.__app.ioc.facade.add_social(media)
        self.__app.ioc.facade.save()
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    def delete(self):
        ids = self.__dialog.content.ids
        media = PersonFacade.Social(
            token=str(ids.token.text).strip(),
            media=list(filter(
                None, ids.media.text.strip().split(' ')))[0].capitalize())
        self.__app.ioc.facade.del_social(media)
        self.__app.ioc.facade.save()
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    class SocialMediaContent(BoxLayout):
        def __init__(self, data, **kwargs):
            self.data = data
            BoxLayout.__init__(self, **kwargs)


Builder.load_string('''
<ProfilePhoto>:
    BoxLayout:
        id: _text_container
        orientation: 'vertical'
        pos: root.pos
        padding: root._txt_left_pad, root._txt_top_pad, root._txt_right_pad, root._txt_bot_pad
        Image:

''')  # noqa E501


class ProfilePhoto(ContainerSupport, BaseListItem):
    pass


Builder.load_string('''
<CameraContent>:
    orientation: 'vertical'
    Camera:
        id: camera
        resolution: (0, 0)
        play: True
        allow_stretch: True
        keep_ration: False
    BoxLayout:
''')  # noqa E501


class CameraDialog:
    def __init__(self, app, parent, data=None):
        self.__app = app
        self.__parent = parent

        content = CameraDialog.CameraContent(
            data=data,
            height=dp(500),
            pos_hint={'center_x': .5, 'center_y': .5},
            size_hint=(2, None))

        self.__dialog = MDDialog(title='Camera', content=content)
        self.__dialog.add_action_button(
            'Capture', action=lambda *x: self.save())
        self.__dialog.add_action_button(
            'Cancel', action=lambda *x: self.cancel())
        self.__dialog.open()

    def save(self):
        width = 512
        camera = self.__dialog.content.ids['camera']
        tex = camera.texture

        size = tex.size[0] if tex.size[0] < tex.size[1] else tex.size[1]
        scale = width / size

        fbo = Fbo(size=(tex.size[0] * scale, tex.size[1] * scale),
                  with_stencilbuffer=True)

        with fbo:
            ClearColor(0, 0, 0, 0)
            ClearBuffers()
            Scale(1, -1, 1)
            Scale(scale, scale, 1)
            Translate(-camera.x, -camera.y - tex.size[1], 0)

        fbo.add(camera.canvas)
        fbo.draw()
        subregion = fbo.texture.get_region(
            math.floor((fbo.texture.size[0] - size) / 2), 0, width, width)

        pixels = bytearray()
        rowlen = width*4
        fullen = width*width*4
        for r in range(fullen, -1, -rowlen):
            pixels += bytearray(subregion.pixels[r:r+rowlen])
        fbo.remove(camera.canvas)

        self.__app.ioc.message.send(
            Messages.profile_picture(Const.W_CLIENT_NAME, pixels, width))

        camera.play = False
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    def cancel(self):
        ids = self.__dialog.content.ids
        ids['camera'].play = False
        self.__dialog.dismiss()
        self.__parent.load(self.__app)

    class CameraContent(BoxLayout):
        def __init__(self, data, **kwargs):
            self.data = data
            BoxLayout.__init__(self, **kwargs)


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
