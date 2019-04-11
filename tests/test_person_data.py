import sys
sys.path.append('../angelos')  # noqa

import json
import datetime
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
