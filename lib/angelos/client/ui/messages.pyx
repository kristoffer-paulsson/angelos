# cython: language_level=3
from kivy.lang import Builder
from kivy.clock import Clock

from .common import BasePanelScreen


Builder.load_string("""
#:import MDLabel kivymd.label.MDLabel
#:import MDCheckbox kivymd.selectioncontrols.MDCheckbox
#:import MDTextField kivymd.textfields.MDTextField
#:import MDBottomNavigation kivymd.bottomnavigation.MDBottomNavigation

#:import MDScrollViewRefreshLayout kivymd.refreshlayout.MDScrollViewRefreshLayout


<MessagesScreen@BasePanelScreen>:
    id: 'messages'
    title: 'Messages'
    # on_pre_enter: self.load()
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
                [['refresh', lambda x: root.refresh_callback()]]
        MDBottomNavigation
            id: person_entity
            tab_display_mode: 'icons'
            MDBottomNavigationItem:
                id: 'inbox'
                text: "Inbox"
                icon: 'inbox-arrow-down'
                MDScrollViewRefreshLayout:
                    id: refresh_inbox
                    refresh_callback: root.refresh_callback
                    root_layout: self
                    MDLabel:
                        font_style: 'Body1'
                        theme_text_color: 'Primary'
                        text: 'I love Python'
                        halign: 'center'
            MDBottomNavigationItem:
                name: 'outbox'
                text: "Outbox"
                icon: 'inbox-arrow-up'
                BoxLayout:
            MDBottomNavigationItem:
                name: 'drafts'
                text: "Drafts"
                icon: 'message-text-outline'
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


class MessagesScreen(BasePanelScreen):
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
