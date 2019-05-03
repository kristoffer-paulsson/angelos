# cython: language_level=3
from kivy.lang import Builder
from kivy.uix.screenmanager import Screen

Builder.load_string('''
#:import MDSpinner kivymd.spinner.MDSpinner
#:import MDLabel kivymd.label.MDLabel


<Spinner>:
    name: 'spinner'
    BoxLayout:
        orientation: 'vertical'
        padding: '50dp'
        MDLabel:
            id: spinner_title
            font_style: 'Display1'
            theme_text_color: 'Primary'
            text: "Setup"
            halign: 'center'
        MDSpinner:
            size: dp(100), dp(100)
            size_hint: None, None
            pos_hint: {'center_x': 0.5}
            halign: 'center'
            active: True
        MDLabel:
            id: spinner_txt
            font_style: 'Body1'
            theme_text_color: 'Primary'
            text: "Your installation of Logo is being configured. Please wait!"
            halign: 'center'
''')  # noqa E501


class Spinner(Screen):
    pass
