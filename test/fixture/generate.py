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
import datetime
import ipaddress
import os
import random
import string
import uuid

from .lipsum import MALE_NAMES, FEMALE_NAMES, LIPSUM_WORDS, CHURCHES, LIPSUM_LINES, SURNAMES


class Generate:
    """Generate proper fake data."""

    @classmethod
    def person_data(cls, num=1):
        """Generate random entity data for number of person entities."""
        identities = []
        for i in range(num):
            sex = random.choices(
                ["man", "woman", "undefined"], [0.495, 0.495, 0.01], k=1
            )[0]
            if sex == "man":
                names = random.choices(MALE_NAMES, k=random.randrange(2, 5))
            elif sex == "woman":
                names = random.choices(FEMALE_NAMES, k=random.randrange(2, 5))
            else:
                names = random.choices(
                    MALE_NAMES + FEMALE_NAMES, k=random.randrange(2, 5)
                )

            born = datetime.date.today() - datetime.timedelta(
                days=random.randrange(4748, 29220)
            )

            entity = dict()
            entity["given_name"] = names[0]
            entity["names"] = names
            entity["family_name"] = random.choices(SURNAMES, k=1)[0].capitalize()
            entity["sex"] = sex
            entity["born"] = born
            identities.append(entity)

        return identities

    @classmethod
    def ministry_data(cls, num=1):
        """Generate random entity data for number of ministry entities."""
        ministries = []
        for i in range(num):
            ministry = random.choices(LIPSUM_WORDS, k=random.randrange(3, 7))
            vision = random.choices(LIPSUM_WORDS, k=random.randrange(20, 25))
            founded = datetime.date.today() - datetime.timedelta(
                days=random.randrange(365, 29220)
            )

            entity = dict()
            entity["ministry"] = " ".join(ministry).capitalize()
            entity["vision"] = " ".join(vision).capitalize()
            entity["founded"] = founded
            ministries.append(entity)

        return ministries

    @classmethod
    def church_data(cls, num=1):
        """Generate random entity data for number of church entities."""
        churches = []
        for i in range(num):
            church = random.choices(CHURCHES, k=1)[0]
            founded = datetime.date.today() - datetime.timedelta(
                days=random.randrange(730, 29220)
            )

            entity = dict()
            entity["founded"] = founded
            entity["city"] = church[0]
            entity["region"] = church[1]
            entity["country"] = church[2]
            churches.append(entity)

        return churches

    @classmethod
    def lipsum(cls, upper: int = 10) -> bytes:
        """Random lipsum data generator."""
        return (
            "\n".join(random.choices(LIPSUM_LINES, k=random.randrange(1, upper)))
        ).encode("utf-8")

    @classmethod
    def lipsum_sentence(cls, upper: int = 10) -> str:
        """Random sentence"""
        return (
            " ".join(random.choices(LIPSUM_WORDS, k=random.randrange(3, upper)))
        ).capitalize()

    @classmethod
    def filename(cls, postfix=".txt"):
        """Random file name generator."""
        return (
                "".join(
                    random.choices(
                        string.ascii_lowercase + string.digits,
                        k=random.randrange(5, 10),
                    )
                )
                + postfix
        )

    @classmethod
    def uuid(cls):
        """Random uuid."""
        return uuid.uuid4()

    @classmethod
    def ipv4(cls):
        """Random uuid."""
        return ipaddress.IPv4Address(os.urandom(4))

    @classmethod
    def new_secret(cls) -> bytes:
        """Generate encryption key.
        Returns (bytes):
            Encryption key
        """
        return os.urandom(32)