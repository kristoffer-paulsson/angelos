import io
import bz2

from kivy.app import App
from kivy.lang import Builder
from kivy.graphics import Rectangle
from kivy.uix.boxlayout import BoxLayout
from kivy.graphics.texture import Texture
from kivymd.theming import ThemeManager

from eidon.codec import EidonEncoder, EidonDecoder
from eidon.image import EidonImage, ImageRGB, ImageRGBA
from eidon.stream import EidonStream

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
<ImageWidget>:
    orientation: 'vertical'
    Image:
        id: picture
    Image:
        id: loaded
        source: 'image.png'
        size_hint: .2, .2
        pos_hint: {'top':.9,'right':.9}
        MDFloatingActionButton:
            icon: 'image'
            elevation_normal: 8
            pos: dp(25), dp(25)
            on_press: root.capture()
''')


class ImageWidget(BoxLayout):
    def capture(self):
        self.ids['loaded'].export_to_png("original-image.png")
        image = self.extract()
        print(len(image.pixels))
        stream = EidonEncoder(image, EidonStream.preferred(
            image.width, image.height)).run()
        print(len(stream.data))
        print(len(bz2.compress(stream.data)))
        self.insert(EidonDecoder(stream, EidonImage.rgb(
            stream.width, stream.height)).run())
        self.ids['picture'].export_to_png("converted-image.png")

    def extract(self):
        tex = self.ids['loaded'].texture
        data = io.BytesIO(tex.pixels)
        data.seek(0)
        if tex.colorfmt == 'rgba':
            image = EidonImage.rgba(tex.width,
                                    tex.height,
                                    bytearray(data.getvalue()))
        elif tex.colorfmt == 'rgb':
            image = EidonImage.rgb(tex.width,
                                   tex.height,
                                   bytearray(data.getvalue()))
        return image

    def insert(self, input):
        if isinstance(input, ImageRGBA):
            fmt = 'rgba'
        elif isinstance(input, ImageRGB):
            fmt = 'rgb'
        tex = Texture.create(size=(input.width, input.height), colorfmt=fmt)
        tex.blit_buffer(input.pixels, colorfmt=fmt, bufferfmt='ubyte')
        with self.ids['picture'].canvas:
            Rectangle(texture=tex, size=self.ids['loaded'].texture.size)


class ImageApp(App):
    theme_cls = ThemeManager()

    def build(self):
        img = ImageWidget()
        return img


ImageApp().run()
