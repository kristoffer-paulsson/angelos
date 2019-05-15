# cython: language_level=3
from kivy.lang import Builder
from kivy.uix.screenmanager import Screen


Builder.load_string("""
#:import MDSeparator kivymd.cards.MDSeparator
#:import MDToolbar kivymd.toolbar.MDToolbar
#:import NavigationLayout kivymd.navigationdrawer.NavigationLayout
#:import MDNavigationDrawer kivymd.navigationdrawer.MDNavigationDrawer
#:import NavigationDrawerSubheader kivymd.navigationdrawer.NavigationDrawerSubheader
#:import NavigationDrawerIconButton kivymd.navigationdrawer.NavigationDrawerIconButton

#:import MDToolbar kivymd.toolbar.MDToolbar
#:import MDRaisedButton kivymd.button.MDRaisedButton

#:import MDTabbedPanel kivymd.tabs.MDTabbedPanel

<BasePanelScreen@Screen>
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
                [['dots-vertical', lambda x: root.parent.parent.parent.parent.toggle_nav_drawer()]]
        Widget:

<MainScreen@Screen>:
    name: 'main'
    on_pre_enter: profile.load(app)
    BoxLayout:
        orientation: 'vertical'
        MDToolbar:
            id: toolbar
            title: 'Λόγῳ'
            md_bg_color: app.theme_cls.bg_light
            background_palette: 'Primary'
            background_hue: '500'
            elevation: 10
            left_action_items:
                [['dots-vertical', lambda x: root.parent.parent.parent.toggle_nav_drawer()]]
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

<MessagesScreen@BasePanelScreen>:
    name: 'messages'
    title: 'Messages'
    # on_pre_enter: profile.load(app)

<ContactsScreen@BasePanelScreen>:
    name: 'contacts'
    title: 'Contacts'
    # on_pre_enter: profile.load(app)

<DocumentsScreen@BasePanelScreen>:
    name: 'documents'
    title: 'Documents'
    # on_pre_enter: profile.load(app)

<FilesScreen@BasePanelScreen>:
    name: 'files'
    title: 'Files'
    # on_pre_enter: profile.load(app)

<NetworksScreen@BasePanelScreen>:
    name: 'networks'
    title: 'Networks'
    # on_pre_enter: profile.load(app)

<ProfileScreen@BasePanelScreen>:
    name: 'profile'
    title: 'Profile'
    # on_pre_enter: profile.load(app)

<SettingsScreen@BasePanelScreen>:
    name: 'settings'
    title: 'Settings'
    # on_pre_enter: profile.load(app)

<ContentNavigationDrawer@MDNavigationDrawer>:
    NavigationDrawerIconButton:
        text: 'Messages'
        icon: 'email-outline'
        on_release: root.parent.parent.ids.scr_mngr.current = 'messages'
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
        ContentNavigationDrawer:
            id: nav_drawer
        # BoxLayout:
        #     orientation: 'vertical'
        ScreenManager:
            id: scr_mngr
            MainScreen:
            MessagesScreen:
            ContactsScreen:
            DocumentsScreen:
            FilesScreen:
            NetworksScreen:
            ProfileScreen:
            SettingsScreen:
""")  # noqa E501


class UserScreen(Screen):
    pass
