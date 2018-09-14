from kivy.app import App
from kivy.lang import Builder
from kivymd.theming import ThemeManager

from .ui import UI


class LogoApp(App):
    theme_cls = ThemeManager()
    title = "Logo"

    def build(self):
        main_widget = Builder.load_string(UI)
        # self.theme_cls.theme_style = 'Dark'
        return main_widget

    def on_pause(self):
        return True

    def on_stop(self):
        pass
