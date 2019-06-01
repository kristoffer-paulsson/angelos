"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import sys
sys.path.append('../angelos')  # noqa

import json
import datetime
import libnacl
import support
from angelos.policy.entity import ChurchGeneratePolicy

# data = support.random_person_entity_data(1)
data = [{
    'founded': datetime.date(2011, 2, 3),
    'city': 'Reno',
    'state': 'Nevada',
    'nation': 'USA'}]
policy = ChurchGeneratePolicy()
policy.generate(**data[0])

print(json.dumps(policy.entity.export_str()))
print(json.dumps(policy.private.export_str()))
print(json.dumps(policy.keys.export_str()))

box = libnacl.sign.Signer()
box2 = libnacl.sign.Signer(box.seed)
print(box.vk == box2.vk)
print(box.seed)
print(box.vk)
print(box2.vk)
