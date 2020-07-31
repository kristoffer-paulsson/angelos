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
"""Provisioning of Vagrant boxes. Python 2 to 3 compatible."""
import platform
import re
import sys
import traceback
from subprocess import Popen, check_call, CalledProcessError, PIPE


def extract_version(version):
    """Extract version from string as dictionary, (major, minor, micro)"""
    major, minor, micro = re.search(r"(\d+).(\d+).(\d+)", version).group(1, 2, 3)
    return {
        "major": int(major),
        "minor": int(minor),
        "micro": int(micro)
    }


def command_exists(cmd):
    """Find out if a command is available at the shell."""
    try:
        check_call("which %s > /dev/null" % cmd, shell=True)
    except CalledProcessError:
        return False
    else:
        return True


CENTOS_7 = """
# Install a build platform on CentOS 7.

sudo yum check-update
sudo yum upgrade -y
sudo yum groupinstall "Development Tools" -y
sudo yum install nano git python36 python36-devel rpmdevtools -y

sudo groupadd angelos
sudo adduser angelos --system -g angelos

sudo mkdir /opt/angelos
sudo mkdir /var/lib/angelos
sudo mkdir /var/log/angelos
sudo mkdir /etc/angelos

# sudo mkdir /run/angelos
# sudo chown -R angelos:angelos /run/angelos

git clone https://github.com/kristoffer-paulsson/angelos.git
cd angelos
# git fetch --tags
# git checkout tags/1.0.0b1

sudo pip3.6 install virtualenv
virtualenv venv -p /usr/bin/python3.6
source venv/bin/activate
pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install -U

pip install -r requirements.txt
python ./setup.py develop
python ./setup.py install

sudo chown -R vagrant:vagrant /opt/angelos
PYTHONUSERBASE=/opt/angelos pip install --user --upgrade --ignore-installed -r scripts/pkg_reqs.txt
python ./setup.py install --prefix /opt/angelos
sudo chown -R angelos:angelos /etc/angelos

sudo cp scripts/env.json /etc/angelos/env.json
sudo cp scripts/config.json /etc/angelos/config.json
sudo touch /var/lib/admins.pub
sudo cp scripts/angelos.service /etc/systemd/system/angelos.service

sudo chown -R angelos:angelos /opt/angelos
sudo chown -R angelos:angelos /var/lib/angelos
sudo chown -R angelos:angelos /var/log/angelos
sudo chown -R angelos:angelos /etc/angelos
"""


def install_centos_8():
    """Install a build platform on CentOS 8."""


SYSTEM = platform.system()
failure = 0


if SYSTEM == "Linux":

    DISTRO, RELEASE, _ = platform.linux_distribution()
    DISTRO = DISTRO.lower().split()[0]
    RELEASE = extract_version(RELEASE)

    if DISTRO == "centos":
        if RELEASE["major"] <= 6:
            SystemError("%s unsupported" % RELEASE)
        elif RELEASE["major"] == 7:
            failure = Popen([CENTOS_7], shell=True).wait()
        elif RELEASE["major"] == 8:
            success = install_centos_8()
        else:
            SystemError("%s not yet supported" % RELEASE)
    elif DISTRO == "debian":
        SystemError("%s not yet supported" % DISTRO)
    elif DISTRO == "ubuntu":
        SystemError("%s not yet supported" % DISTRO)
    else:
        raise SystemError("Unknown Linux distribution: %s" % DISTRO)

elif SYSTEM == "Windows":

    pass

else:

    raise SystemError("Unknown system: %s" % platform.system())

if failure:
    exit(failure)
