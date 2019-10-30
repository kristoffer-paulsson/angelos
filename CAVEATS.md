# Caveats to Heed

If you don't heed those caveats, suit your self!

Angelos is a project with many requirements that affects a lot of design decisions. It is a client/server system that is mainly prototyped in Python, it should work at as many platforms as possible in as many formats available.

Server wise it should support Windows, Linux (several) and BSD's while it is written in Python, being compiled using Cython and bundled with PyInstaller and distributed as RPM and Deb packages.

Client wise it should support macOS, Windows, Linux (with various desktops), iOS and Android. Written in Python, compiled by Cython, bundled and distributed with PyInstaller/Buildozer and others. With a ton of packages with sub dependencies behaving differently depending on the platform, Python version, and packaging methods.

This is a major headache and requires a lot of attention!

## The Caveats:

### 1. Don't code in \_\_init__ files
Don't put any code or business logic within the package \_\_init__ files. Especially don't import and export classes and functions here! PyInstaller in combination with Cython is unable to see the difference between modules and sub-packages with the same name. Therefore PyInstaller gets confused and goes nuts:
* Either goes into an infinite recursive loop at compile-time, or
* Can't load modules at runtime.

### 2. Link Logo Messenger with Python 3.8
The Logo Messenger distribution for macOS must be linked using Python 3.8 because of a bug in how subprocesses are spawned. This is vital for the __keyring__ module which __plyer__ depends on. This is necessary for the client to be able to store keys and passwords securely on macOS. If the subprocesses are spawned the wrong way keyring can't access the macOS keyring.

### 3. Don't build Kivy with Anaconda
Building a Kivy application with Anaconda kivy package is not recommended. The conda kivy builds applications with __pygame__ which is deprecated, and don't support high resolution screens.
