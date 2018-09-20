from kivy.uix.boxlayout import BoxLayout
from ...utils import Util
from .default import DefaultNavigation
from .setup import EntityPersonGuide


class InterfaceManager(BoxLayout):
    def __init__(self, configured, **kwargs):
        self.orientation = 'vertical'
        BoxLayout.__init__(self, **kwargs)

        Util.is_type(configured, bool)
        if configured:
            self.show_default()
        else:
            self.show_setup()

    def show_setup(self):
        self.clear_widgets()
        self.add_widget(EntityPersonGuide())

    def show_default(self):
        self.clear_widgets()
        self.add_widget(DefaultNavigation())
