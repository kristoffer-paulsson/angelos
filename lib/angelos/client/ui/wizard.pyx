# cython: language_level=3
from kivy.lang import Builder
from kivy.uix.screenmanager import Screen


Builder.load_string("""
#:import MDLabel kivymd.label.MDLabel
# #:import Screen kivy.uix.screenmanager.Screen

<SetupScreen@Screen>:
    BoxLayout:
        size_hint_y: None
        # height: '100'
        spacing: '10dp'
        # pos_hint: {'center_y': .5}
        Widget:
        MDIconButton:
            icon: 'account'
        Widget:

    BoxLayout:
        size_hint_y: None
        # height: '100'
        spacing: '10dp'
        # pos_hint: {'center_y': .5}
        Widget:
        MDIconButton:
            icon: 'sword'
        MDIconButton:
            icon: 'church'
            text_color: app.theme_cls.primary_color

""")  # noqa E501


class SetupScreen(Screen):
    pass
