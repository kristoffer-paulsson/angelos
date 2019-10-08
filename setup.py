#!/usr/bin/env python
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Angelos build script."""
from glob import glob
from setuptools import setup
from Cython.Build import cythonize


DESCRIPTION = """
"""


setup(
    name="angelos",
    version='0.2a0.dev0',
    license='MIT',
    description='A safe messaging system',
    author='Kristoffer Paulsson',
    author_email='kristoffer.paulsson@talenten.se',
    long_description=DESCRIPTION,
    long_description_content_type='text/markdown',
    url='https://github.com/kristoffer-paulsson/angelos',
    # project_urls={
    #    "Bug Tracker": "https://bugs.example.com/HelloWorld/",
    #    "Documentation": "https://docs.example.com/HelloWorld/",
    #    "Source Code": "https://code.example.com/HelloWorld/",
    # }
    classifiers=[
        'Development Status :: 2 - Pre-Alpha',
        'Environment :: Console',
        'Environment :: Handhelds/PDA\'s',
        # 'Environment :: MacOS X',
        # 'Environment :: Win32 (MS Windows)',
        'Environment :: No Input/Output (Daemon)',
        # 'Environment :: X11 Applications :: Gnome',
        'Framework :: AsyncIO',
        'Intended Audience :: Developers',
        # 'Intended Audience :: End Users/Desktop',
        'Intended Audience :: Information Technology',
        'Intended Audience :: Religion',
        'Intended Audience :: System Administrators',
        'Intended Audience :: Telecommunications Industry',
        'License :: OSI Approved :: MIT License',
        'Operating System :: MacOS :: MacOS X',
        'Operating System :: Microsoft :: Windows',
        'Operating System :: POSIX',
        # 'Programming Language :: C',
        'Programming Language :: Cython',
        'Programming Language :: Python :: 3.7',
        'Topic :: Communications :: Chat',
        'Topic :: Communications :: Email',
        'Topic :: Communications :: File Sharing',
        'Topic :: Documentation',
        'Topic :: Internet',
        'Topic :: Religion',
        'Topic :: Security',
        'Topic :: System :: Archiving',
        'Topic :: Utilities',
    ],
    zip_safe=False,
    test_suite='',
    python_requires='~=3.7',
    setup_requires=[
        'cython', 'pyinstaller', 'kivy', 'libnacl', 'plyer', 'asyncssh',
        'keyring', 'msgpack', 'broqer'],  # kivymd
    install_requires=[],
    # namespace_packages=['angelos', 'eidon'],
    packages=['angelos', 'eidon'],

    scripts=glob('bin/*'),
    ext_modules=cythonize('lib/angelos/**/*.pyx', build_dir="build")
)

# cython
# pyinstaller
# kivy
# kivymd
# libnacl
# plyer
# asyncssh
# keyring
# msgpack
# pyyaml
