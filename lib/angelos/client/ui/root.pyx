# cython: language_level=3
from kivy.lang import Builder
from kivy.uix.screenmanager import Screen


Builder.load_string("""
<BasePanelScreen@Screen>:
    title: ''
    id: ''
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
        Widget:
""")  # noqa E501


class BasePanelScreen(Screen):
    def __init__(self, app, **kwargs):
        Screen.__init__(self, **kwargs)
        self.app = app

    def load(self):
        pass


Builder.load_string("""
<MessagesScreen@BasePanelScreen>:
    name: 'messages'
    title: 'Messages'
    # on_pre_enter: self.load()
""")  # noqa E501


class MessagesScreen(BasePanelScreen):
    pass


Builder.load_string("""
<ContactsScreen@BasePanelScreen>:
    name: 'contacts'
    title: 'Contacts'
    # on_pre_enter: self.load()
""")  # noqa E501


class ContactsScreen(BasePanelScreen):
    pass


Builder.load_string("""
<DocumentsScreen@BasePanelScreen>:
    name: 'documents'
    title: 'Documents'
    # on_pre_enter: self.load()
""")  # noqa E501


class DocumentsScreen(BasePanelScreen):
    pass


Builder.load_string("""
<FilesScreen@BasePanelScreen>:
    name: 'files'
    title: 'Files'
    # on_pre_enter: self.load()
""")  # noqa E501


class FilesScreen(BasePanelScreen):
    pass


Builder.load_string("""
<NetworksScreen@BasePanelScreen>:
    name: 'networks'
    title: 'Networks'
    # on_pre_enter: self.load()
""")  # noqa E501


class NetworksScreen(BasePanelScreen):
    pass


Builder.load_string("""
<ProfileScreen@BasePanelScreen>:
    name: 'profile'
    title: 'Profile'
    # on_pre_enter: self.load()
""")  # noqa E501


class ProfileScreen(BasePanelScreen):
    pass


Builder.load_string("""
<SettingsScreen@BasePanelScreen>:
    name: 'settings'
    title: 'Settings'
    # on_pre_enter: self.load()
""")  # noqa E501


class SettingsScreen(BasePanelScreen):
    pass


Builder.load_string("""
<MainScreen@Screen>:
    name: 'main'
    on_pre_enter: profile.load(app)
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


Builder.load_string("""
#:import MDSeparator kivymd.cards.MDSeparator
#:import MDToolbar kivymd.toolbar.MDToolbar
#:import NavigationLayout kivymd.navigationdrawer.NavigationLayout
#:import MDNavigationDrawer kivymd.navigationdrawer.MDNavigationDrawer
#:import NavigationDrawerSubheader kivymd.navigationdrawer.NavigationDrawerSubheader
#:import NavigationDrawerIconButton kivymd.navigationdrawer.NavigationDrawerIconButton

#:import MDToolbar kivymd.toolbar.MDToolbar
#:import MDRaisedButton kivymd.button.MDRaisedButton

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
        text: 'Documents'
        icon: 'verified'
        on_release: root.ids.scr_mngr.current = 'documents'
    NavigationDrawerIconButton:
        text: 'Files'
        icon: 'file-document'
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
            NavigationDrawerIconButton:
                text: 'Messages'
                icon: 'email-outline'
                on_release: root.goto_messages(app)
            NavigationDrawerIconButton:
                text: 'Contacts'
                icon: 'contact-mail'
                on_release: root.goto_contacts(app)
            NavigationDrawerIconButton:
                text: 'Documents'
                icon: 'verified'
                on_release: root.goto_documents(app)
            NavigationDrawerIconButton:
                text: 'Files'
                icon: 'file-document'
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
        self.switch(MainScreen(app, name='main'))

    def goto_messages(self, app):
        self.switch(MessagesScreen(app, name='messages'))

    def goto_contacts(self, app):
        self.switch(ContactsScreen(app, name='contacts'))

    def goto_documents(self, app):
        self.switch(DocumentsScreen(app, name='documents'))

    def goto_files(self, app):
        self.switch(FilesScreen(app, name='files'))

    def goto_networks(self, app):
        self.switch(NetworksScreen(app, name='networks'))

    def goto_profile(self, app):
        self.switch(ProfileScreen(app, name='profile'))

    def goto_settings(self, app):
        self.switch(SettingsScreen(app, name='settings'))

    def switch(self, screen):
        """Switch to another main screen."""
        old = self.ids.scr_mngr.current

        self.ids.scr_mngr.add_widget(screen)
        self.ids.scr_mngr.current = screen.name

        screen = self.ids.scr_mngr.get_screen(old)
        self.ids.scr_mngr.remove_widget(screen)
