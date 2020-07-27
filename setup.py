#!/usr/bin/env python
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""Angelos build script."""
import os

import pip
from setuptools import setup
from setuptools.command.develop import develop
from setuptools.command.install import install


class NamespacePackageMixin:
    """Install namespace packages."""

    NAMESPACES = {
        "angelos.setup": "angelos-setup/",
    }

    def namespace_packages(self, develop: bool = False):
        """ Use pip to install all microlibraries.  """
        work_dir = os.getcwd()
        for key, value in self.NAMESPACES.iteritems():
            try:
                os.chdir(os.path.join(work_dir, value.root_dir))
                if develop:
                    pip.main(["install", "-e", "."])
                else:
                    pip.main(["install", "."])
            except Exception as exc:
                print("Oops, something went wrong installing", key)
                print(exc)
            finally:
                os.chdir(work_dir)


class CustomDevelop(develop, NamespacePackageMixin):
    """Custom steps for develop command."""

    def run(self):
        self.namespace_packages(True)
        develop.run(self)


class CustomInstall(install, NamespacePackageMixin):
    """Custom steps for install command."""

    def run(self):
        self.namespace_packages()
        install.run(self)


NAME = "angelos.lib"
VERSION = "1.0.0b1"
RELEASE = ""


config = {
    "name": NAME,
    "version": VERSION,
    "license": "MIT",
    "description": "A safe messaging system",
    "author": __author__,
    "author_email": __author_email__,
    "long_description": long_description,
    "long_description_content_type": "text/markdown",
    "url": __url__,
          # project_urls={
          #    "Bug Tracker": "https://bugs.example.com/HelloWorld/",
          #    "Documentation": "https://docs.example.com/HelloWorld/",
          #    "Source Code": "https://code.example.com/HelloWorld/",
          # }
    "cmdclass": {
        "install": CustomInstall,
        "develop": CustomDevelop
    },
    "classifiers": [
        "Development Status :: 2 - Pre-Alpha",
        "Environment :: Console",
        "Environment :: Handhelds/PDA\'s",
        # "Environment :: MacOS X",
        # "Environment :: Win32 (MS Windows)",
        "Environment :: No Input/Output (Daemon)",
        # "Environment :: X11 Applications :: Gnome",
        "Framework :: AsyncIO",
        "Intended Audience :: Developers",
        # "Intended Audience :: End Users/Desktop",
        "Intended Audience :: Information Technology",
        "Intended Audience :: Religion",
        "Intended Audience :: System Administrators",
        "Intended Audience :: Telecommunications Industry",
        "License :: OSI Approved :: MIT License",
        "Operating System :: MacOS :: MacOS X",
        "Operating System :: Microsoft :: Windows",
        "Operating System :: POSIX",
        # "Programming Language :: C",
        "Programming Language :: Cython",
        "Programming Language :: Python :: 3.7",
        "Topic :: Communications :: Chat",
        "Topic :: Communications :: Email",
        "Topic :: Communications :: File Sharing",
        "Topic :: Documentation",
        "Topic :: Internet",
        "Topic :: Religion",
        "Topic :: Security",
        "Topic :: System :: Archiving",
        "Topic :: Utilities",
    ],
    "install_requires": [],
    "python_requires": "'>=3.6, <4",
}


setup(**config)