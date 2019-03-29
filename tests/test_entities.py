import sys
sys.path.append('../angelos')  # noqa

import random
import datetime

from lipsum import MALE_NAMES, FEMALE_NAMES, SURNAMES


def random_identity(self, num):
    identities = []
    for i in range(num):
        chance = random.randrange(1, 100)
        if 1 <= chance <= 49:
            gender = 'man'
            names = random.choice(MALE_NAMES, k=random.randrange(2, 5))
        elif 50 <= chance <= 98:
            gender = 'woman'
            names = random.choice(FEMALE_NAMES, k=random.randrange(2, 5))
        else:
            gender = 'undefined'
            names = random.choice(
                MALE_NAMES + FEMALE_NAMES, k=random.randrange(2, 5))

        born = datetime.date.today(
            ) - datetime.timedelta(days=random.randrange(4748, 29220))

        identities.append({
            'given_name': names[0],
            'names': names,
            'family_name': random.choice(SURNAMES, k=1)[0].capitalize(),
            'gender': gender,
            'born': born
        })

    return identities
