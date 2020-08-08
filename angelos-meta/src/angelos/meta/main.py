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
from argparse import ArgumentParser


def parser():
    parser = ArgumentParser("Package command parser.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "--vagrant", dest="vagrant",
        choices=["centos7", "centos8", "debian10"]
    )
    return parser.parse_args()


def vagrant(distro: str):
    cwd = Path(os.getcwd())
    root = cwd.joinpath("vagrant")
    data = root.joinpath("data")

    cwd.mkdir(exist_ok=True)
    root.mkdir(exist_ok=True)
    data.mkdir(exist_ok=True)

    import angelos.meta.package
    provision = Path(inspect.getfile(angelos.meta.package)).parent
    shutil.copyfile(str(provision.joinpath("provision.py")), str(data.joinpath("provision.py")))
    shutil.copyfile(str(provision.joinpath(distro)), str(root.joinpath("Vagrantfile")))

    # shutil.copytree(angelos_path)
    # shutil.copytree(angelos_path)
    # shutil.copytree(angelos_path)
    # shutil.copytree(angelos_path)
    # shutil.copytree(angelos_path)
    # shutil.copytree(angelos_path)
    # shutil.copytree(angelos_path)

    subprocess.check_call("vagrant up", shell=True, cwd=str(root))


def start():
    args = parser()
    if args.vagrant:
        # import angelos.meta.package
        # angelos = Path(inspect.getfile(angelos.meta.package)).parents[5]
        vagrant(args.vagrant)
