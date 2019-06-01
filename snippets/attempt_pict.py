"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import random
import io
from kivy.graphics.texture import Texture
from kivy.graphics import Rectangle
from kivy.uix.image import Image
from kivy.app import App
from kivy.lang import Builder
from kivy.uix.boxlayout import BoxLayout


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

''')


class TestApp(App):

    def build(self):
        resolution = (1280, 720)
        format = 'rgb'
        box = BoxLayout()
        image = Image(allow_stretch=True, keep_ratio=False)
        stream = io.BytesIO()
        stream.seek(0)
        tex = Texture.create(size=resolution, colorfmt=format)
        tex.blit_buffer(stream.getvalue(), colorfmt=format, bufferfmt='ubyte')
        with image.canvas:
            Rectangle(texture=tex, size=(1600, 1200))
        # box.add_widget(image)
        return image


TestApp().run()
