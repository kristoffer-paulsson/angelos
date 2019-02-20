import json
import re
import datetime

path = './tests/dummy.json'
identities = []
str_num = re.compile('\d+')
str_name = re.compile('[^\d]+')

with open(path) as dummy:
    dummies = json.loads(dummy.read())

cnt = 0
for i in dummies['results']:
    try:
        identities.append({
            'id': i['login']['uuid'],
            'given_name': i['name']['first'].capitalize(),
            'names': [i['name']['first'].capitalize()],
            'family_name': i['name']['last'].capitalize(),
            'social': [],
            'email': i['email'],
            'mobile': i['cell'],
            'phone': i['phone'],
            'address': {
                'co': None,
                'street': str_name.findall(
                    i['location']['street'])[0].strip('\n\r\t ').capitalize(),
                'number': str_num.findall(i['location']['street'])[0],
                'address2': None,
                'zip': i['location']['postcode'],
                'city': i['location']['city'].capitalize(),
                'state': i['location']['state'].capitalize(),
                'country': i['nat'].upper()
            },
            'language': ['English'],
            'birth': datetime.datetime.strptime(
                i['dob']['date'], "%Y-%m-%dT%H:%M:%S%z").strftime(
                    '%Y-%m-%d %H:%M:%S'),
            'gender': 'man' if i['gender'] == 'male' else 'woman' if i['gender'] == 'female' else 'undefined',  # noqa E501
            'picture': i['picture']['large']
        })
        cnt += 1
        if cnt > 100:
            break
    except Exception as e:
        print(e)

print(json.dumps(identities))
