"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import io
import random
import math

from kivy.app import App
from kivy.lang import Builder
from kivy.graphics import Rectangle
from kivy.uix.boxlayout import BoxLayout
from kivy.graphics.texture import Texture
from kivymd.theming import ThemeManager

from attempt_color import Eidon

"""
def __init__(self, **kwargs):
    super(...).__init__(**kwargs)
    self.texture = Texture.create(size=(512, 512), colorfmt='RGB',
        bufferfmt='ubyte')
    self.texture.add_reload_observer(self.populate_texture)

    # and load the data now.
    self.cbuffer = '\x00\xf0\xff' * 512 * 512
    self.populate_texture(self.texture)

def populate_texture(self, texture):
    texture.blit_buffer(self.cbuffer)
"""


Builder.load_string('''
#:import MDFloatingActionButton kivymd.button.MDFloatingActionButton
<CameraWidget>:
    orientation: 'vertical'
    Image:
        id: picture
    Camera:
        id: camera
        resolution: (0, 0)
        play: True
        size_hint: 1, 1
#        pos_hint: {'top': 1,'right': 1}
        MDFloatingActionButton:
            icon: 'camera'
            elevation_normal: 8
            pos: dp(25), dp(25)
            on_press: root.capture()
''')


class CameraWidget(BoxLayout):
    def capture(self):
        data = self.extract()
        print(len(data.data))
        # image = Eidon.encode(data, None)
        # print(len(image))
        # self.insert(Eidon.decode(image, 1280, 720))

    def extract(self):
        tex = self.ids['camera'].texture
        if tex.colorfmt == 'rgba':
            fmt = Eidon.Format.RGBA
        elif tex.colorfmt == 'rgb':
            fmt = Eidon.Format.RGB

        # tex.flip_vertical()
        data = io.BytesIO(tex.pixels)
        data.seek(0)
        print(tex.size)
        return Eidon.Image(
            fmt,
            tex.size[0],
            tex.size[1],
            data.getvalue()
        )

    def insert(self, input):
        if input.format == Eidon.Format.RGBA:
            fmt = 'rgba'
        elif input.format == Eidon.Format.RGB:
            fmt = 'rgb'

        tex = Texture.create(size=(input.width, input.height), colorfmt=fmt)
        tex.blit_buffer(input.data, colorfmt=fmt, bufferfmt='ubyte')
        with self.ids['picture'].canvas:
            Rectangle(texture=tex, size=self.ids['camera'].texture.size)


class CameraApp(App):
    theme_cls = ThemeManager()

    def build(self):
        cam = CameraWidget()
        return cam


CameraApp().run()
