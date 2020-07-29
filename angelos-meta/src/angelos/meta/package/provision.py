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
from subprocess import Popen, check_call, CalledProcessError


def extract_version(version):
    """Extract version from string as dictionary, (major, minor, micro)"""
    return dict(zip(
        ["major", "minor", "micro"],
        re.search(r"(\d+).(\d+).(\d+)", version).group(1, 2, 3)
    ))


def command_exists(cmd):
    """Find out if a command is available at the shell."""
    try:
        check_call("which %s > /dev/null" % cmd, shell=True)
    except CalledProcessError:
        return False
    else:
        return True


def install_centos_7():
    """Install a build platform on CentOS 7."""
    try:
        Popen("sudo yum check update", shell=True)
        Popen("sudo yum upgrade -y", shell=True)
        Popen("sudo yum groupinstall \"Development Tools\" -y", shell=True)
        Popen("sudo yum install nano git python36 python36-devel virtualenv -y", shell=True)
        Popen("sudo yum install virtualenv -y", shell=True)
        Popen("sudo yum install rpmdevtools -y", shell=True)

        Popen("sudo groupadd angelos", shell=True)
        Popen("sudo adduser angelos --system -g angelos", shell=True)

        Popen("sudo mkdir /opt/angelos", shell=True)
        Popen("sudo mkdir /var/lib/angelos", shell=True)
        Popen("sudo mkdir /var/log/angelos", shell=True)
        Popen("sudo mkdir /etc/angelos", shell=True)

        Popen("git clone https://github.com/kristoffer-paulsson/angelos.git", shell=True)
        Popen("cd angelos", shell=True)

        Popen("sudo pip3.6 install -r requirements.txt", shell=True)
        Popen("sudo python3.6 ./setup.py develop", shell=True)
        Popen("sudo python3.6 ./setup.py install", shell=True)

        Popen("sudo chown -R vagrant:vagrant /opt/angelos", shell=True)
        Popen("PYTHONUSERBASE=/opt/angelos pip3.6 install --user --upgrade --ignore-installed -e .", shell=True)
        Popen("python3.6 ./setup.py install --prefix /opt/angelos", shell=True)
        Popen("sudo chown -R angelos:angelos /etc/angelos", shell=True)

        Popen("sudo cp scripts/env.json /etc/angelos/env.json", shell=True)
        Popen("sudo cp scripts/config.json /etc/angelos/config.json", shell=True)
        Popen("sudo touch /var/lib/admins.pub", shell=True)
        Popen("sudo cp scripts/angelos.service /etc/systemd/system/angelos.service", shell=True)

        Popen("sudo chown -R angelos:angelos /opt/angelos", shell=True)
        Popen("sudo chown -R angelos:angelos /var/lib/angelos", shell=True)
        Popen("sudo chown -R angelos:angelos /var/log/angelos", shell=True)
        Popen("sudo chown -R angelos:angelos /etc/angelos", shell=True)

    except CalledProcessError:
        return False


def install_centos_8():
    """Install a build platform on CentOS 8."""


SYSTEM = platform.system()


if SYSTEM == "Linux":

    DISTRO, RELEASE, _ = platform.linux_distribution()
    DISTRO = DISTRO.lower().split()[0]
    RELEASE = extract_version(RELEASE)

    if DISTRO == "centos":
        if RELEASE["major"] <= 6:
            SystemError("%s unsupported" % RELEASE)
        elif RELEASE["major"] == 7:
            install_centos_7()
        elif RELEASE["major"] == 8:
            install_centos_8()
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
