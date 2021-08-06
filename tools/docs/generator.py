#
# Copyright (c) 2018-2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
import os
from pathlib import Path

from angelostools.nsscanner import NamespacePackageScanner


TEMPLATE_PACKAGE = """
{0}
{2}

.. toctree::
    :maxdepth: 1
    :caption: Contents:
   
    {1}

"""

TEMPLATE_NAMESPACE = """
{0}
{2}

.. automodule:: {0}
    :members:
    :undoc-members:
    :show-inheritance:

.. toctree::
    :maxdepth: 1
    :caption: Contents:
   
    {1}

"""

TEMPLATE_MODULE = """
{0}
{1}

.. automodule:: {0}
    :members:
    :undoc-members:
    :show-inheritance:
"""


class DocGenerator:

    def __init__(self, name: str):
        self._name = name
        self._path = Path(os.getcwd())
        self._docs = self._path.joinpath("docs/api")
        self._pkgs = dict()

    @property
    def path(self) -> Path:
        return self._path

    def filename(self, module: str):
        return self._docs.joinpath(module.replace(".", "_") + ".rst")

    def index(self):
        """Index all packages and modules."""
        scanner = NamespacePackageScanner(self._name, self._path)
        for nspkg in scanner.pkg_iter():
            package = scanner.pkg_name(nspkg).replace("-", ".")
            modules = list()
            for mod in scanner.mod_iter(nspkg):
                if bool(mod) and "__init__" not in str(mod):
                    modules.append(scanner.mod_imp_path(mod))
            self._pkgs[package] = modules

    def run(self):
        self.index()
        self.write_package("\n    ".join([pkg.replace(".", "_") + ".rst" for pkg in self._pkgs.keys()]))
        for nspkg in self._pkgs.keys():
            self.write_namespace(nspkg, "\n    ".join([pkg.replace(".", "_") + ".rst" for pkg in self._pkgs[nspkg]]))
            for module in self._pkgs[nspkg]:
                self.write_module(module)
        print("Run \033[92mpython setup.py build_sphinx\033[0m to generate html documentation.")

    def write_package(self, toc: str):
        with open(self._docs.joinpath(self._name + ".rst"), "w") as file:
            file.write(TEMPLATE_PACKAGE.format(self._name, toc, "="*len(self._name)))

    def write_namespace(self, pkg: str, toc: str):
        print("Namespace:", pkg)
        with open(self._docs.joinpath(pkg.replace(".", "_") + ".rst"), "w") as file:
            file.write(TEMPLATE_NAMESPACE.format(pkg, toc, "="*len(pkg)))

    def write_module(self, pkg: str):
        with open(self._docs.joinpath(pkg.replace(".", "_") + ".rst"), "w") as file:
            file.write(TEMPLATE_MODULE.format(pkg, "="*len(pkg)))


