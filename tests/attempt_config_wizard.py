from datetime import date
from kivy.app import App
from kivy.lang import Builder
from kivy.metrics import dp
from kivy.properties import ObjectProperty
from kivy.uix.screenmanager import Screen
from kivymd.label import MDLabel
from kivymd.dialog import MDDialog
from kivymd.date_picker import MDDatePicker
from kivymd.theming import ThemeManager


main_widget_kv = '''
#:import ThemeManager kivymd.theming.ThemeManager
#:import MDCheckbox kivymd.selectioncontrols.MDCheckbox
#:import MDTextField kivymd.textfields.MDTextField
#:import get_color_from_hex kivy.utils.get_color_from_hex
#:import colors kivymd.color_definitions.colors
#:import MDTabbedPanel kivymd.tabs.MDTabbedPanel
#:import MDTab kivymd.tabs.MDTab

<EntityPersonGuide>:
    MDTabbedPanel
        id: person
        tab_display_mode: 'icons'
        MDTab:
            name: 'info'
            text: "Person"
            icon: 'information-outline'
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: None
                width: root.width
                padding: '25dp'
                spacing: '25dp'
                valign: 'top'
                MDLabel:
                    font_style: 'Headline'
                    theme_text_color: 'Primary'
                    text: "Welcome!"
                    halign: 'left'
                    valign: 'top'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Primary'
                    text: "You have just installed the client app Logo, which is a part of the Angelos city church network. This network is for Christians and Seekers, to communicate with each other in a safe and secure manner."
                    halign: 'justify'
                    valign: 'top'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Primary'
                    text: "This network prioritizes kindness, honesty and safety. That implies that the focus is on privazy and verifiability, but not anonymity!"
                    halign: 'justify'
                    valign: 'top'
                MDLabel:
                    font_style: 'Headline'
                    theme_text_color: 'Primary'
                    text: "Who are you?"
                    halign: 'justify'
                    valign: 'top'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Primary'
                    text: "It is necessary to create a digital identity for you. You need to fill out the form in this guide. It can not be changed later! This guide will produce a unique identity for you, which is known to the network as an Entity document of type Person."
                    halign: 'justify'
                    valign: 'top'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Error'
                    text: "Truthfulness is expected of you. False identities are forbidden!"
                    halign: 'justify'
                    valign: 'top'
                BoxLayout:
                    orientation: 'horizontal'
                    size_hint_y: None
                    spacing: '25dp'
                    MDRaisedButton:
                        text: "I agree"
                        on_release: app.root.ids.person.current = 'name'
                    MDFlatButton:
                        text: "Decline"
                        on_release: app.stop()

        MDTab:
            name: 'name'
            text: "Name"
            icon: 'account-outline'
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: None
                width: root.width
                padding: '25dp'
                spacing: '25dp'
                valign: 'top'
                MDLabel:
                    font_style: 'Headline'
                    theme_text_color: 'Primary'
                    text: "Name"
                    halign: 'justify'
                    valign: 'top'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Primary'
                    text: "The name is very important for other people to know who you are. We ask that you be completely truthful about this."
                    halign: 'justify'
                    valign: 'top'
                MDTextField:
                    id: given_name
                    hint_text: "Given name"
                    helper_text: "Your legal first name"
                    helper_text_mode: "persistent"
                    required: True
                    multiline: False
                    color_mode: 'custom'
                    line_color_focus: self.theme_cls.opposite_bg_normal
                    valign: 'top'
                MDTextField:
                    id: names
                    hint_text: "Names"
                    helper_text: "Your full name (given + middle names)"
                    helper_text_mode: "persistent"
                    required: True
                    multiline: False
                    color_mode: 'custom'
                    line_color_focus: self.theme_cls.opposite_bg_normal
                    valign: 'top'
                MDTextField:
                    id: family_name
                    hint_text: "Family name"
                    helper_text: "Your legal family name"
                    helper_text_mode: "persistent"
                    required: True
                    multiline: False
                    color_mode: 'custom'
                    line_color_focus: self.theme_cls.opposite_bg_normal
                    valign: 'top'
                MDRaisedButton:
                    text: "Next"
                    on_release: app.name_validate()
        MDTab:
            name: 'gender'
            text: "Gender"
            icon: 'gender-male-female'
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: None
                width: root.width
                padding: '25dp'
                spacing: '25dp'
                MDLabel:
                    font_style: 'Headline'
                    theme_text_color: 'Primary'
                    text: "Gender"
                    halign: 'justify'
                    valign: 'top'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Primary'
                    text: "About gender in question, others needs to know if you are a man or a woman. Only if you don't know you may choose Undefined. What is your biological sex?"
                    halign: 'justify'
                    valign: 'top'
                GridLayout:
                    cols: 3
                    MDLabel:
                        text: 'Woman'
                        halign: 'center'
                    MDLabel:
                        text: 'Man'
                        halign: 'center'
                    MDLabel:
                        text: 'Undefined'
                        halign: 'center'
                    MDCheckbox:
                        id: woman
                        group: 'gender'
                    MDCheckbox:
                        id: man
                        group: 'gender'
                    MDCheckbox:
                        id: 3rd
                        group: 'gender'
                MDRaisedButton:
                    text: "Next"
                    on_release: app.gender_validate()
        MDTab:
            name: 'birth'
            text: "Birth"
            icon: 'calendar'
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: None
                width: root.width
                padding: '25dp'
                spacing: '25dp'
                valign: 'top'
                MDLabel:
                    font_style: 'Headline'
                    theme_text_color: 'Primary'
                    text: "Date of birth"
                    halign: 'justify'
                    valign: 'top'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Primary'
                    text: "Your date of birth is needed."
                    halign: 'justify'
                    valign: 'top'
                BoxLayout:
                    orientation: 'horizontal'
                    spacing: '25dp'
                    valign: 'top'
                    MDTextField:
                        id: born
                        hint_text: "Date of birth"
                        helper_text: "(YYYY-MM-DD)"
                        helper_text_mode: "persistent"
                        required: True
                        multiline: False
                        color_mode: 'custom'
                        line_color_focus: self.theme_cls.opposite_bg_normal
                        valign: 'top'
                    MDRaisedButton:
                        text: "Date"
                        on_release: app.born_datepicker()
                        valign: 'top'
                MDLabel:
                    font_style: 'Headline'
                    theme_text_color: 'Primary'
                    text: "Confirmation"
                    halign: 'justify'
                    valign: 'top'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Primary'
                    text: "Please confirm that all information you have given is truthful and correct. If you are not sure you can go back and take an extra look on the other tabs."
                    halign: 'justify'
                    valign: 'top'
                MDRaisedButton:
                    text: "Confirm"
                    on_release: app.confirm()

EntityPersonGuide:
    name: 'person'
'''


class EntityPersonGuide(Screen):
    pass


class KitchenSink(App):
    theme_cls = ThemeManager()
    previous_date = ObjectProperty()
    title = "KivyMD Kitchen Sink"
    person = {'given_name': None, 'family_name': None, 'names': None, 'gender': None, 'born': None}

    def build(self):
        main_widget = Builder.load_string(main_widget_kv)
        #self.theme_cls.theme_style = 'Dark'
        print(main_widget)
        return main_widget

    def show_alert(self, title, message):
        content = MDLabel(
            font_style='Body1', theme_text_color='Error',
            text=message, size_hint_y=None, valign='top')
        content.bind(texture_size=content.setter('size'))

        self.dialog = MDDialog(
            title=title, content=content, size_hint=(.8, None),
            height=dp(200), auto_dismiss=False)

        self.dialog.add_action_button(
            "Dismiss", action=lambda *x: self.dialog.dismiss())
        self.dialog.open()

    def show_confirm(self, title, message):
        pass

    def show_prompt(self, title, message):
        pass

    def name_validate(self):
        self.person['given_name'] = self.root.ids.given_name.text.strip()
        self.person['names'] = self.root.ids.names.text.strip().split(' ')
        self.person['family_name'] = self.root.ids.family_name.text.strip()
        err = False
        if not bool(self.person['given_name']):
            err = True
        if not bool(self.person['family_name']):
            err = True
        if not bool(self.person['names']):
            err = True
        if self.person['given_name'] not in self.person['names']:
            err = True
        if err:
            self.show_alert('Error', 'The names given are either incomplete ' +
                            'or your given name is not mentioned in the ' +
                            'names field!')
        else:
            self.root.ids.person.current = 'gender'

    def gender_validate(self):
        if self.root.ids.woman.active:
            self.person['gender'] = 'woman'
        elif self.root.ids.man.active:
            self.person['gender'] = 'man'
        elif self.root.ids["3rd"].active:
            self.person['gender'] = 'undefined'
        else:
            self.person['gender'] = None
        err = False
        if not bool(self.person['gender']):
            err = True
        if err:
            self.show_alert('Error', 'There is not gender set!')
        else:
            self.root.ids.person.current = 'birth'

    def confirm(self):
        self.person['given_name'] = self.root.ids.given_name.text.strip()
        self.person['names'] = self.root.ids.names.text.strip().split(' ')
        self.person['family_name'] = self.root.ids.family_name.text.strip()
        if self.root.ids.woman.active:
            self.person['gender'] = 'woman'
        elif self.root.ids.man.active:
            self.person['gender'] = 'man'
        elif self.root.ids["3rd"].active:
            self.person['gender'] = 'undefined'
        else:
            self.person['gender'] = None
        self.person['born'] = self.root.ids.born.text.strip()

        err = False
        if not bool(self.person['given_name']):
            err = True
        if not bool(self.person['family_name']):
            err = True
        if not bool(self.person['names']):
            err = True
        if not bool(self.person['gender']):
            err = True
        if not bool(self.person['born']):
            err = True

        if self.person['given_name'] not in self.person['names']:
            err = True
        if self.person['gender'] not in ['woman', 'man', 'undefined']:
            err = True
        try:
            date.fromisoformat(self.person['born'])
        except ValueError:
            err = True

        if err:
            self.show_alert('Error', 'The information you have given is ' +
                            'either invalid or incomplete. Please review ' +
                            'the form again!')
        else:
            return True  # Implement next step

    def set_born(self, date_obj):
        self.person['born'] = date_obj
        self.root.ids.born.text = str(date_obj)

    def born_datepicker(self):
            try:
                pd = date.fromisoformat(self.root.ids.born.text)
                MDDatePicker(self.set_born,
                             pd.year, pd.month, pd.day).open()
            except (AttributeError, ValueError):
                MDDatePicker(self.set_born).open()

    def on_pause(self):
        return True

    def on_stop(self):
        pass


if __name__ == '__main__':
    KitchenSink().run()
