from kivy.lang import Builder
from kivymd.navigationdrawer import NavigationLayout


Builder.load_string('''
#:import MDNavigationDrawer kivymd.navigationdrawer.MDNavigationDrawer


<DefaultNavigation>:
    id: nav_layout
    MDNavigationDrawer:
        id: nav_drawer
        NavigationDrawerIconButton:
            icon: 'checkbox-blank-circle'
            text: "Page 1"
            on_release: app.root.ids.scr_mngr.current = 'p1'
        NavigationDrawerIconButton:
            icon: 'checkbox-blank-circle'
            text: "Page 2"
            on_release: app.root.ids.scr_mngr.current = 'p2'
        NavigationDrawerIconButton:
            icon: 'checkbox-blank-circle'
            text: "Page 3"
            on_release: app.root.ids.scr_mngr.current = 'p3'
    BoxLayout:
        orientation: 'vertical'
        Toolbar:
            id: toolbar
            title: 'Logo - messenger'
            md_bg_color: app.theme_cls.primary_color
            background_palette: 'Primary'
            background_hue: '500'
            left_action_items: [ \
            ['menu', lambda x: app.root.toggle_nav_drawer()]]
            right_action_items: []
        ScreenManager:
            id: scr_mngr
            Screen:
                name: 'p1'
                BoxLayout:
                    size_hint: None, None
                    size: '200dp', '50dp'
                    padding: '12dp'
                    pos_hint: {'center_x': 0.75, 'center_y': 0.8}
                    MDLabel:
                        font_style: 'Body1'
                        theme_text_color: 'Primary'
                        text: "Page 1"
                        size_hint_x:None
                        width: '56dp'
            Screen:
                name: 'p2'
                BoxLayout:
                    size_hint: None, None
                    size: '200dp', '50dp'
                    padding: '12dp'
                    pos_hint: {'center_x': 0.75, 'center_y': 0.8}
                    MDLabel:
                        font_style: 'Body1'
                        theme_text_color: 'Primary'
                        text: "Page 2"
                        size_hint_x:None
                        width: '56dp'

            Screen:
                name: 'p3'
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
''')


class DefaultNavigation(NavigationLayout):
    pass
