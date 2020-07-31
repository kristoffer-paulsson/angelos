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
import os
import inspect
import shutil
import subprocess
from pathlib import Path


def vagrant(cwd, angelos):
    cwd = Path(os.getcwd())
    root = cwd.joinpath("vagrant")
    data = root.joinpath("data")

    cwd.mkdir(exist_ok=True)
    root.mkdir(exist_ok=True)
    data.mkdir(exist_ok=True)

    import angelos.meta.package
    provision = Path(inspect.getfile(angelos.meta.package)).parent
    shutil.copyfile(str(provision.joinpath("provision.py")), str(data.joinpath("provision.py")))
    shutil.copyfile(str(provision.joinpath("Vagrantfile")), str(root.joinpath("Vagrantfile")))

    # shutil.copytree(angelos)
    # shutil.copytree(angelos)
    # shutil.copytree(angelos)
    # shutil.copytree(angelos)
    # shutil.copytree(angelos)
    # shutil.copytree(angelos)
    # shutil.copytree(angelos)

    subprocess.check_call("vagrant up", shell=True, cwd=str(root))


def start():
    cwd = Path(os.getcwd())
    import angelos.meta.package
    angelos = Path(inspect.getfile(angelos.meta.package)).parents[5]
    vagrant(cwd, angelos)
