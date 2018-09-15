from kivy.app import App
from kivy.lang import Builder
from kivy.metrics import dp
from kivy.properties import ObjectProperty
from kivy.uix.image import Image
from kivy.uix.boxlayout import BoxLayout

from kivymd.bottomsheet import MDListBottomSheet, MDGridBottomSheet
from kivymd.button import MDIconButton
from kivymd.date_picker import MDDatePicker
from kivymd.dialog import MDDialog
from kivymd.label import MDLabel
from kivymd.list import ILeftBody, ILeftBodyTouch, IRightBodyTouch, BaseListItem
from kivymd.material_resources import DEVICE_TYPE
from kivymd.navigationdrawer import MDNavigationDrawer, NavigationDrawerHeaderBase
from kivymd.selectioncontrols import MDCheckbox
from kivymd.snackbar import Snackbar
from kivymd.theming import ThemeManager
from kivymd.time_picker import MDTimePicker

main_widget_kv = '''
#:import Toolbar kivymd.toolbar.Toolbar
#:import ThemeManager kivymd.theming.ThemeManager
#:import MDNavigationDrawer kivymd.navigationdrawer.MDNavigationDrawer
#:import NavigationLayout kivymd.navigationdrawer.NavigationLayout
#:import NavigationDrawerDivider kivymd.navigationdrawer.NavigationDrawerDivider
#:import NavigationDrawerToolbar kivymd.navigationdrawer.NavigationDrawerToolbar
#:import NavigationDrawerSubheader kivymd.navigationdrawer.NavigationDrawerSubheader
#:import MDCheckbox kivymd.selectioncontrols.MDCheckbox
#:import MDSwitch kivymd.selectioncontrols.MDSwitch
#:import MDList kivymd.list.MDList
#:import OneLineListItem kivymd.list.OneLineListItem
#:import TwoLineListItem kivymd.list.TwoLineListItem
#:import ThreeLineListItem kivymd.list.ThreeLineListItem
#:import OneLineAvatarListItem kivymd.list.OneLineAvatarListItem
#:import OneLineIconListItem kivymd.list.OneLineIconListItem
#:import OneLineAvatarIconListItem kivymd.list.OneLineAvatarIconListItem
#:import MDTextField kivymd.textfields.MDTextField
#:import MDSpinner kivymd.spinner.MDSpinner
#:import MDCard kivymd.card.MDCard
#:import MDSeparator kivymd.card.MDSeparator
#:import MDDropdownMenu kivymd.menu.MDDropdownMenu
#:import get_color_from_hex kivy.utils.get_color_from_hex
#:import colors kivymd.color_definitions.colors
#:import SmartTile kivymd.grid.SmartTile
#:import MDSlider kivymd.slider.MDSlider
#:import MDTabbedPanel kivymd.tabs.MDTabbedPanel
#:import MDTab kivymd.tabs.MDTab
#:import MDProgressBar kivymd.progressbar.MDProgressBar
#:import MDAccordion kivymd.accordion.MDAccordion
#:import MDAccordionItem kivymd.accordion.MDAccordionItem
#:import MDAccordionSubItem kivymd.accordion.MDAccordionSubItem
#:import MDThemePicker kivymd.theme_picker.MDThemePicker
#:import MDBottomNavigation kivymd.tabs.MDBottomNavigation
#:import MDBottomNavigationItem kivymd.tabs.MDBottomNavigationItem

BoxLayout:
    orientation: 'vertical'
    MDTabbedPanel
        id: person
        tab_display_mode: 'text'
        MDTab:
            name: 'info'
            text: "Person"
            icon: 'account'
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: None
                width: root.width
                padding: '25dp'
                spacing: 25
                MDLabel:
                    font_style: 'Headline'
                    theme_text_color: 'Primary'
                    text: "Welcome!"
                    halign: 'left'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Primary'
                    text: "You have just installed the client app Logo, which is a part of the Angelos city church network. This network is for Christians and Seekers, to communicate with each other in a safe and secure manner."
                    halign: 'left'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Primary'
                    text: "This network prioritizes kindness, honesty and safety. That implies that the focus is on privazy and verifiability, but not anonymity!"
                    halign: 'left'
                MDLabel:
                    font_style: 'Headline'
                    theme_text_color: 'Primary'
                    text: "Who are you?"
                    halign: 'left'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Primary'
                    text: "It is necessary to create a digital identity for you. You need to fill out the form in this guide. It can not be changed later! This guide will produce a unique identity for you, which is known to the network as an Entity document of type Person."
                    halign: 'left'
                MDLabel:
                    font_style: 'Body1'
                    theme_text_color: 'Error'
                    text: "Truthfulness is expected of you. False identities are forbidden!"
                    halign: 'left'
                BoxLayout:
                    orientation: 'horizontal'
                    size_hint_y: None
                    spacing: 25
                    MDRaisedButton:
                        text: "I agree"
                    MDFlatButton:
                        text: "Decline"

        MDTab:
            name: 'name'
            text: "Name"
            icon: 'account'
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: None
                width: root.width
                padding: '25dp'
                spacing: 25
                MDTextField:
                    id: given_name
                    hint_text: "Given name"
                    helper_text: "Your legal first name"
                    helper_text_mode: "persistent"
                    required: True
                    multiline: False
                    color_mode: 'custom'
                    line_color_focus: self.theme_cls.opposite_bg_normal
                MDTextField:
                    id: names
                    hint_text: "Names"
                    helper_text: "Your full name (given + middle names)"
                    helper_text_mode: "persistent"
                    required: True
                    multiline: False
                    color_mode: 'custom'
                    line_color_focus: self.theme_cls.opposite_bg_normal
                MDTextField:
                    id: family_name
                    hint_text: "Family name"
                    helper_text: "Your legal family name"
                    helper_text_mode: "persistent"
                    required: True
                    multiline: False
                    color_mode: 'custom'
                    line_color_focus: self.theme_cls.opposite_bg_normal
                MDRaisedButton:
                    text: "Next"
        MDTab:
            name: 'gender'
            text: "Gender"
            icon: 'account'
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: None
                width: root.width
                padding: '25dp'
                spacing: 25
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
        MDTab:
            name: 'birth'
            text: "Birth"
            icon: 'account'
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: None
                width: root.width
                padding: '25dp'
                spacing: 25
                BoxLayout:
                    orientation: 'horizontal'
                    spacing: '25dp'
                    MDTextField:
                        id: born
                        hint_text: "Date of birth"
                        helper_text: "(YYYY-MM-DD)"
                        helper_text_mode: "persistent"
                        required: True
                        multiline: False
                        color_mode: 'custom'
                        line_color_focus: self.theme_cls.opposite_bg_normal
                    MDRaisedButton:
                        text: "Date"
                        on_release: app.show_example_date_picker()
                MDRaisedButton:
                    text: "Confirm"

'''


class KitchenSink(App):
    theme_cls = ThemeManager()
    previous_date = ObjectProperty()
    title = "KivyMD Kitchen Sink"

    def build(self):
        main_widget = Builder.load_string(main_widget_kv)
        #self.theme_cls.theme_style = 'Dark'
        return main_widget

    def get_time_picker_data(self, instance, time):
        self.root.ids.time_picker_label.text = str(time)
        self.previous_time = time

    def show_example_time_picker(self):
        self.time_dialog = MDTimePicker()
        self.time_dialog.bind(time=self.get_time_picker_data)
        if self.root.ids.time_picker_use_previous_time.active:
            try:
                self.time_dialog.set_time(self.previous_time)
            except AttributeError:
                pass
        self.time_dialog.open()

    def set_previous_date(self, date_obj):
        print(date_obj)
        self.previous_date = date_obj
        self.root.ids.born.text = str(date_obj)

    def show_example_date_picker(self):
            pd = self.previous_date
            try:
                MDDatePicker(self.set_previous_date,
                             pd.year, pd.month, pd.day).open()
            except AttributeError:
                MDDatePicker(self.set_previous_date).open()

    def on_pause(self):
        return True

    def on_stop(self):
        pass


if __name__ == '__main__':
    KitchenSink().run()
