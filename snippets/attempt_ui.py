
from kivy.app import App
from kivy.lang import Builder
from kivy.factory import Factory
from kivymd.theming import ThemeManager
Builder.load_string('''
#:import MDToolbar kivymd.toolbar.MDToolbar
#:import MDTextField kivymd.textfields.MDTextField
#:import MDTextFieldClear kivymd.textfields.MDTextFieldClear
#:import MDTextFieldRect kivymd.textfields.MDTextFieldRect
<ExampleTextFields@BoxLayout>
    orientation: 'vertical'
    MDToolbar:
        id: toolbar
        title: app.title
        md_bg_color: app.theme_cls.primary_color
        background_palette: 'Primary'
        elevation: 10
        left_action_items: [['dots-vertical', lambda x: None]]
    ScrollView:
        BoxLayout:
            orientation: 'vertical'
            size_hint_y: None
            height: self.minimum_height
            padding: dp(48)
            spacing: dp(15)
            MDTextFieldRound:
                hint_text: 'Password'
                icon: 'lock-outline'
                active_color: [0, 0, 0, .2]
                normal_color: [0, 0, 0, .5]
            MDTextField:
                hint_text: "No helper text"
            MDTextField:
                hint_text: "Helper text on focus"
                helper_text: "This will disappear when you click off"
                helper_text_mode: "on_focus"
            MDTextField:
                hint_text: "Persistent helper text"
                helper_text: "Text is always here"
                helper_text_mode: "persistent"
            Widget:
                size_hint_y: None
                height: dp(5)
            MDTextField:
                id: text_field_error
                hint_text: "Helper text on error (Hit Enter with  two characters here)"
                helper_text: "Two is my least favorite number"
                helper_text_mode: "on_error"
            MDTextField:
                hint_text: "Max text length = 10"
                max_text_length: 10
            MDTextField:
                hint_text: "required = True"
                required: True
                helper_text_mode: "on_error"
            MDTextField:
                multiline: True
                hint_text: "Multi-line text"
                helper_text: "Messages are also supported here"
                helper_text_mode: "persistent"
            MDTextField:
                hint_text: "color_mode = \'accent\'"
                color_mode: 'accent'
            MDTextField:
                hint_text: "color_mode = \'custom\'"
                color_mode: 'custom'
                helper_text_mode: "on_focus"
                helper_text: "Color is defined by \'line_color_focus\' property"
                line_color_focus: self.theme_cls.opposite_bg_normal
            MDTextField:
                hint_text: "disabled = True"
                disabled: True
            MDTextFieldRect:
                size_hint: None, None
                size: app.Window.width - dp(40), dp(30)
                pos_hint: {'center_y': .5, 'center_x': .5}
            Widget:
                size_hint_y: None
                height: dp(5)
            MDTextFieldClear:
                hint_text: "Text field with clearing type"
''')
class Example(App):
    theme_cls = ThemeManager()
    theme_cls.primary_palette = 'Blue'
    title = "Example Text Fields"
    main_widget = None
    def build(self):
        return Factory.ExampleTextFields()
Example().run()
