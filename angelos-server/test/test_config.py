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
import collections
import json
import os
from unittest import TestCase

from angelos.lib.ioc import ContainerAware, Config, Container
from angelos.server.parser import Parser
from angelos.server.server import Bootstrap, AdminKeys, Auto
from angelos.server.vars import ENV_IMMUTABLE, ENV_DEFAULT, CONFIG_IMMUTABLE, CONFIG_DEFAULT


class Configuration(Config, Container):
    def __init__(self):
        Container.__init__(self, self.__config())

    def __load(self, filename):
        try:
            full_path = os.path.join(self.auto.conf_dir, filename)
            with open(full_path) as jc:
                return json.load(jc)
        except FileNotFoundError as exc:
            print("Configuration file not found ({})".format(full_path))
            return {}

    def __config(self):
        return {
            "env": lambda self: collections.ChainMap(
                ENV_IMMUTABLE,
                {key:value for key, value in vars(self.opts).items() if value},
                self.__load("env.json"),
                vars(self.auto),
                ENV_DEFAULT,
            ),
            "config": lambda self: collections.ChainMap(
                CONFIG_IMMUTABLE,
                self.__load("config.json"),
                CONFIG_DEFAULT
            ),
            "bootstrap": lambda self: Bootstrap(self.env, self.keys),
            "keys": lambda self: AdminKeys(self.env),
            "opts": lambda self: Parser(),
            "auto": lambda self: Auto("Angelos"),
        }


class ServerStub(ContainerAware):
    def __init__(self):
        ContainerAware.__init__(self, Configuration())


class TestConfig(TestCase):
    def test_server(self):
        server = ServerStub()

        print(server.ioc.env)
        for key in server.ioc.env:
            pass
            # print("ENV;    {}: {}".format(key, server.ioc.env[key]))

        for key in server.ioc.config:
            pass
            # print("CONFIG; {}: {}".format(key, server.ioc.config[key]))