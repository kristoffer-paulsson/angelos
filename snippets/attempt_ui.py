from kivy.app import App
from kivy.uix.textinput import TextInput
from kivy.lang import Builder
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.floatlayout import FloatLayout
from kivy.properties import NumericProperty, ListProperty, BooleanProperty, ObjectProperty
from kivy.uix.recycleview import RecycleView
from kivy.uix.recyclegridlayout import RecycleGridLayout
from kivy.uix.recycleview.views import RecycleDataViewBehavior
from kivy.uix.label import Label
from kivy.uix.recycleboxlayout import RecycleBoxLayout
from kivy.uix.behaviors import FocusBehavior
from kivy.uix.recycleview.layout import LayoutSelectionBehavior

Builder.load_string('''
<Body>:
    canvas:
        Color:
            rgba:(1, 1, 1, 1)
        Rectangle:
            pos: self.pos
            size: self.size


<DropDownWidget>:
    canvas:
        Color:
            rgba:(1, 1, 1, 1)
        Rectangle:
            pos: self.pos
            size: self.size

    orientation: 'vertical'
    spacing: 2
    txt_input: txt_input
    rv: rv

    MyTextInput:
        id: txt_input
        size_hint_y: None
        height: 50
    RV:
        id: rv

<MyTextInput>:
    readonly: False
    multiline: False

<SelectableLabel>:
    # Draw a background to indicate selection
    color: 0,0,0,1
    canvas.before:
        Color:
            rgba: (0, 0, 1, .5) if self.selected else (1, 1, 1, 1)
        Rectangle:
            pos: self.pos
            size: self.size
<RV>:
    canvas:
        Color:
            rgba: 0,0,0,.2

        Line:
            rectangle: self.x +1 , self.y, self.width - 2, self.height -2

    bar_width: 10
    scroll_type:['bars']
    viewclass: 'SelectableLabel'
    SelectableRecycleBoxLayout:
        default_size: None, dp(20)
        default_size_hint: 1, None
        size_hint_y: None
        height: self.minimum_height
        orientation: 'vertical'
        multiselect: False
        ''')

class SelectableRecycleBoxLayout(FocusBehavior, LayoutSelectionBehavior,
                                 RecycleBoxLayout):
    ''' Adds selection and focus behaviour to the view. '''


class SelectableLabel(RecycleDataViewBehavior, Label):
    ''' Add selection support to the Label '''
    index = None
    selected = BooleanProperty(False)
    selectable = BooleanProperty(True)

    def refresh_view_attrs(self, rv, index, data):
        ''' Catch and handle the view changes '''
        self.index = index
        return super(SelectableLabel, self).refresh_view_attrs(
            rv, index, data)

    def on_touch_down(self, touch):
        ''' Add selection on touch down '''
        if super(SelectableLabel, self).on_touch_down(touch):
            return True
        if self.collide_point(*touch.pos) and self.selectable:
            return self.parent.select_with_touch(self.index, touch)

    def apply_selection(self, rv, index, is_selected):
        ''' Respond to the selection of items in the view. '''
        self.selected = is_selected
        if is_selected:
            print("selection changed to {0}".format(rv.data[index]))

class RV(RecycleView):
    def __init__(self, **kwargs):
        super(RV, self).__init__(**kwargs)

class DropDownWidget(BoxLayout):
    txt_input = ObjectProperty()
    rv = ObjectProperty()

class MyTextInput(TextInput):
    txt_input = ObjectProperty()
    flt_list = ObjectProperty()
    word_list = ListProperty()
    #this is the variable storing the number to which the look-up will start
    starting_no = NumericProperty(3)
    suggestion_text = ''

    def __init__(self, **kwargs):
        super(MyTextInput, self).__init__(**kwargs)

    def on_text(self, instance, value):
        #find all the occurrence of the word
        self.parent.ids.rv.data = []
        matches = [self.word_list[i] for i in range(len(self.word_list)) if self.word_list[i][:self.starting_no] == value[:self.starting_no]]
        #display the data in the recycleview
        display_data = []
        for i in matches:
            display_data.append({'text':i})
        self.parent.ids.rv.data = display_data
        #ensure the size is okay
        if len(matches) <= 10:
            self.parent.height = (50 + (len(matches)*20))
        else:
            self.parent.height = 240

    def keyboard_on_key_down(self, window, keycode, text, modifiers):
        if self.suggestion_text and keycode[1] == 'tab':
            self.insert_text(self.suggestion_text + ' ')
            return True
        return super(MyTextInput, self).keyboard_on_key_down(window, keycode, text, modifiers)

class Body(FloatLayout):
    def __init__(self, **kwargs):
        super(Body, self).__init__(**kwargs)
        widget_1 = DropDownWidget(pos_hint = {'center_x':.5,'center_y':.5}, \
                               size_hint = (None, None), size = (600, 60))
        widget_1.ids.txt_input.word_list = ['how to use python', 'how to use kivy', 'how to ...']
        widget_1.ids.txt_input.starting_no = 3
        self.add_widget(widget_1)

class MyApp(App):

    def build(self):
        return Body()

if __name__ == "__main__":
    MyApp().run()
