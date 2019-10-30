# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring"""
from kivy.lang import Builder
from kivy.uix.screenmanager import Screen


Builder.load_string("""
#:kivy 1.0
#:import kivy kivy
#:import win kivy.core.window

<StartScreen@Screen>
    FloatLayout:
        canvas:
            Color:
                rgba: .85, .85, .85, 1
            Rectangle:
                size: self.size
                pos: self.pos

        BoxLayout:
            padding: dp(25)
            spacing: dp(25)
            Image:
                source: './art/angelos.png'
""")


class StartScreen(Screen):
    pass
