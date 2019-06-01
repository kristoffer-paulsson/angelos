"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
from kivy.app import App
from kivy.properties import ObjectProperty
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.scatter import Scatter
from kivy.clock import Clock


class CamViewer(Scatter):
    image_texture = ObjectProperty(None)

    def change_texture(self, instance, value):
        self.image_texture = value
        return

    def update_texture(self, dt):
        self.image_texture = self.ids.camera1.texture
        return


class OtherViewer(Scatter):
    image_texture = ObjectProperty(None)

    def update_texture(self, dt):
        self.ids.image1.texture = self.image_texture
        self.ids.image1.canvas.ask_update()
        self.canvas.ask_update()
        return


class CameraTestApp(App):
    image_texture = ObjectProperty(None)

    def build(self):
        root = FloatLayout()
        orgCam = CamViewer()
        copyCam = OtherViewer()
        root.add_widget(orgCam)
        root.add_widget(copyCam)
        orgCam.ids.camera1.bind(on_texture=orgCam.change_texture)

        Clock.schedule_interval(copyCam.update_texture, 0)
        Clock.schedule_interval(orgCam.update_texture, 0)

        return root


if __name__ == '__main__':
    CameraTestApp().run()
