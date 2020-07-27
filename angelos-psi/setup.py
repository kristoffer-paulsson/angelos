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
from setuptools import setup, find_namespace_packages

setup(name="angelos.psi",
      version="1.0.0b1",
      package_dir={"": "src"},
      packages=find_namespace_packages(where="src", include=["angelos.*"]))