ROOT = """
#:import MDSeparator kivymd.cards.MDSeparator
#:import MDToolbar kivymd.toolbar.MDToolbar
#:import NavigationLayout kivymd.navigationdrawer.NavigationLayout
#:import MDNavigationDrawer kivymd.navigationdrawer.MDNavigationDrawer
#:import NavigationDrawerSubheader kivymd.navigationdrawer.NavigationDrawerSubheader

<ContentNavigationDrawer@MDNavigationDrawer>:
    NavigationDrawerSubheader:
        text: "Menu:"

NavigationLayout:
    id: nav_layout
    ContentNavigationDrawer:
        id: nav_drawer
    BoxLayout:
        orientation: 'vertical'
        MDToolbar:
            id: toolbar
            title: 'Λόγῳ'
            md_bg_color: root.theme_cls.bg_light
            background_palette: 'Primary'
            background_hue: '500'
            elevation: 10
            left_action_items:
                [['dots-vertical', lambda x: app.root.toggle_nav_drawer()]]
        Widget:
"""  # noqa E501

MAIN = """
#:import MDSeparator kivymd.cards.MDSeparator
#:import MDToolbar kivymd.toolbar.MDToolbar
#:import NavigationLayout kivymd.navigationdrawer.NavigationLayout
#:import MDNavigationDrawer kivymd.navigationdrawer.MDNavigationDrawer
#:import NavigationDrawerSubheader kivymd.navigationdrawer.NavigationDrawerSubheader

#:import MDToolbar kivymd.toolbar.MDToolbar
#:import MDRaisedButton kivymd.button.MDRaisedButton

#:import MDTabbedPanel kivymd.tabs.MDTabbedPanel
<ContentNavigationDrawer@MDNavigationDrawer>:
    NavigationDrawerSubheader:
        text: "Menu:"

NavigationLayout:
    id: nav_layout
    ContentNavigationDrawer:
        id: nav_drawer
    BoxLayout:
        orientation:'vertical'
        MDToolbar:
            id: toolbar
            title: 'Λόγῳ'
            md_bg_color: root.theme_cls.bg_light
            background_palette: 'Primary'
            background_hue: '500'
            elevation: 10
            left_action_items:
                [['dots-vertical', lambda x: app.root.toggle_nav_drawer()]]
        MDBottomNavigation:
            MDBottomNavigationItem:
                name: 'home'
                text: 'Home'
                icon: 'home'
            MDBottomNavigationItem:
                name: 'search'
                text: 'Search'
                icon: 'magnify'
            MDBottomNavigationItem:
                name: 'notes'
                text: 'Notifications'
                icon: 'bell'
            MDBottomNavigationItem:
                name: 'messages'
                text: 'Inbox'
                icon: 'inbox'
"""  # noqa E501
