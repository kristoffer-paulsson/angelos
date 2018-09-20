import datetime
from kivy.lang import Builder
from kivy.metrics import dp
from kivy.uix.screenmanager import ScreenManager
from kivymd.label import MDLabel
from kivymd.dialog import MDDialog
from kivymd.date_picker import MDDatePicker

from ...const import Const
from ...document.entity import Person
from ..events import Messages

Builder.load_string('''
#:import MDCheckbox kivymd.selectioncontrols.MDCheckbox
#:import MDTextField kivymd.textfields.MDTextField
#:import MDTabbedPanel kivymd.tabs.MDTabbedPanel
#:import MDTab kivymd.tabs.MDTab
#:import MDSpinner kivymd.spinner.MDSpinner


<EntityPersonGuide>:
    id: scm_setup
    Screen:
        name: 'guide'
        MDTabbedPanel:
            id: person_entity
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
                            on_release: person_entity.current = 'name'
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
                        on_release: scm_setup.name_validate()
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
                        on_release: scm_setup.gender_validate()
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
                            on_release: person_entity.born_datepicker()
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
                        on_release: scm_setup.confirm(app)
    Screen:
        name: 'spinner'
        BoxLayout:
            orientation: 'vertical'
            padding: '50dp'
            MDLabel:
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
                font_style: 'Body1'
                theme_text_color: 'Primary'
                text: "Your installation of Logo is being configured. Please wait!"
                halign: 'center'
''')  # noqa E501


class EntityPersonGuide(ScreenManager):
    entity = Person()
    confirmed = False

    def set_born(self, date_obj):
        self.entity.born = date_obj
        self.ids.born.text = str(date_obj)

    def born_datepicker(self):
        try:
            pd = datetime.date.fromisoformat(self.ids.born.text)
            MDDatePicker(self.set_born,
                         pd.year, pd.month, pd.day).open()
        except (AttributeError, ValueError):
            MDDatePicker(self.set_born).open()

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

    def name_validate(self):
        err = False
        try:
            self.entity.given_name = self.ids.given_name.text.strip()
            self.entity.names = list(filter(
                None, self.ids.names.text.strip().split(' ')))
            self.entity.family_name = self.ids.family_name.text.strip()

            if self.entity.given_name not in self.entity.names:
                err = True
        except (AttributeError, TypeError):
            err = True

        if err:
            self.show_alert('Error', 'The names given are either incomplete ' +
                            'or your given name is not mentioned in the ' +
                            'names field!')
        else:
            self.ids.person_entity.current = 'gender'

    def gender_validate(self):
        err = False
        try:
            if self.ids.woman.active:
                self.entity.gender = 'woman'
            elif self.ids.man.active:
                self.entity.gender = 'man'
            elif self.ids["3rd"].active:
                self.entity.gender = 'undefined'
            else:
                self.entity.gender = None
        except AttributeError:
            err = True
        # if not bool(self.entity.gender):
        #    err = True
        if err:
            self.show_alert('Error', 'There is not gender set!')
        else:
            self.ids.person_entity.current = 'birth'

    def confirm(self, app):
        err = False
        try:
            self.entity.given_name = self.ids.given_name.text.strip()
            self.entity.names = self.entity.names = list(filter(
                None, self.ids.names.text.strip().split(' ')))
            self.entity.family_name = self.ids.family_name.text.strip()
            if self.ids.woman.active:
                self.entity.gender = 'woman'
            elif self.ids.man.active:
                self.entity.gender = 'man'
            elif self.ids["3rd"].active:
                self.entity.gender = 'undefined'
            else:
                self.entity.gender = None

            self.entity.born = datetime.date.fromisoformat(
                self.ids.born.text.strip())

            if self.entity.given_name not in self.entity.names:
                err = True
        except (AttributeError, ValueError, TypeError):
            err = True

        if err:
            self.show_alert('Error', 'The information you have given is ' +
                            'either invalid or incomplete. Please review ' +
                            'the form again!')
        else:
            self.current = 'spinner'
            app.ioc.message.send(
                Messages.setup(
                    Const.W_CLIENT_NAME, self.entity, Const.R_TYPE_CLIENT))
