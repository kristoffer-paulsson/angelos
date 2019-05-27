
from kivy.app import App
from kivy.clock import Clock
from kivy.lang import Builder
from kivy.factory import Factory
from kivymd.button import MDIconButton
from kivymd.icon_definitions import md_icons
from kivymd.theming import ThemeManager


Builder.load_string('''
#:import MDToolbar kivymd.toolbar.MDToolbar
#:import MDScrollViewRefreshLayout kivymd.refreshlayout.MDScrollViewRefreshLayout
<Example@FloatLayout>
    BoxLayout:
        orientation: 'vertical'
        MDToolbar:
            title: app.title
            md_bg_color: app.theme_cls.primary_color
            background_palette: 'Primary'
            elevation: 10
            left_action_items: [['menu', lambda x: x]]
        MDScrollViewRefreshLayout:
            id: refresh_layout
            refresh_callback: app.refresh_callback
            root_layout: root
            GridLayout:
                id: box
                cols: 30
                rows: 150
                height: self.minimum_height
''')


class Example(App):
    title = 'Example Refresh Layout'
    theme_cls = ThemeManager()
    screen = None
    x = 0
    y = 15

    def build(self):
        self.screen = Factory.Example()
        self.set_list()
        return self.screen

    def set_list(self):
        names_icons_list = list(md_icons.keys())  # [self.x:self.y]
        box = self.screen.ids.box
        for name_icon in names_icons_list:
            btn = MDIconButton()
            btn.icon = name_icon
            btn.text = name_icon
            box.add_widget(btn)

    def refresh_callback(self, *args):
        '''A method that updates the state of your application
        while the spinner remains on the screen.'''
        print(args)

        def refresh_callback(interval):
            self.screen.ids.box.clear_widgets()
            if self.x == 0:
                self.x, self.y = 15, 30
            else:
                self.x, self.y = 0, 15
            self.set_list()
            self.screen.ids.refresh_layout.refresh_done()
            self.tick = 0
        Clock.schedule_once(refresh_callback, 1)


Example().run()
