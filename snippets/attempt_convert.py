"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import os
import glob
import json


lang_path = os.path.realpath('.') + '/lib/angelos/data/languages/*.js'
country_path = os.path.realpath('.') + '/lib/angelos/data/countries/*.js'

langs = {}
for f in sorted(glob.glob(lang_path)):
    with open(f) as fd:
        obj = {}
        loaded = json.loads(fd.read())
        for key in sorted(loaded.keys()):
            if len(key) == 2:
                obj[key] = loaded[key]
    langs[f[-5:-3]] = obj

print(langs)


"""cntrs = {}
for f in sorted(glob.glob(country_path)):
    with open(f) as fd:
        obj = {}
        loaded = json.loads(fd.read())
        for key in sorted(loaded.keys()):
            if len(key) == 2:
                obj[key] = loaded[key]
    cntrs[f[-5:-3]] = obj

print(cntrs)"""
