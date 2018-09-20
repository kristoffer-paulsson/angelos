from kivy.app import App
from kivy.lang import Builder
from kivymd.theming import ThemeManager

main_widget_kv = '''
#:import Toolbar kivymd.toolbar.Toolbar
#:import MDTextField kivymd.textfields.MDTextField
#:import MDSpinner kivymd.spinner.MDSpinner

Screen:
    name: 'setup'
    BoxLayout:
        orientation: 'vertical'
        padding: '50dp'
        MDLabel:
            font_style: 'Display1'
            theme_text_color: 'Primary'
            text: "Setup"
            halign: 'center'
        MDSpinner:
            id: spinner
            size: dp(100), dp(100)
            size_hint: None, None
            pos_hint: {'center_x': 0.5}
            halign: 'center'
            active: True
        MDLabel:
            font_style: 'Body1'
            theme_text_color: 'Primary'
            text: "Your installation of Logo is being configured. Please wait!"
            halign: 'center'
'''  # noqa E501


class KitchenSink(App):
    theme_cls = ThemeManager()
    title = "KivyMD Kitchen Sink"

    def build(self):
        main_widget = Builder.load_string(main_widget_kv)
        # self.theme_cls.theme_style = 'Dark'
        return main_widget

    def on_pause(self):
        return True

    def on_stop(self):
        pass


if __name__ == '__main__':
    KitchenSink().run()
