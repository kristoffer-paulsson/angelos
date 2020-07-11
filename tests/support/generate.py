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
"""Generators for dummy data."""

import asyncio
import datetime
import functools
import io
import ipaddress
import os
import random
import string
import uuid

from tests.support.lipsum import (
    SURNAMES,
    MALE_NAMES,
    FEMALE_NAMES,
    LIPSUM_LINES,
    LIPSUM_WORDS,
    CHURCHES,
)


def run_async(coro):
    """Decorator for asynchronous test cases."""

    @functools.wraps(coro)
    def wrapper(*args, **kwargs):
        """Execute the coroutine with asyncio.run()"""
        return asyncio.run(coro(*args, **kwargs))

    return wrapper


def filesize(file):
    """Real file filesize reader."""
    if isinstance(file, io.IOBase):
        return os.fstat(file.fileno()).st_size
    else:
        return os.stat(file).st_size


class Generate:
    @staticmethod
    def person_data(num=1):
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

    @staticmethod
    def ministry_data(num=1):
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

    @staticmethod
    def church_data(num=1):
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

    @staticmethod
    def lipsum() -> bytes:
        """Random lipsum data generator."""
        return (
            "\n".join(random.choices(LIPSUM_LINES, k=random.randrange(1, 10)))
        ).encode("utf-8")

    @staticmethod
    def lipsum_sentence() -> str:
        """Random sentence"""
        return (
            " ".join(random.choices(LIPSUM_WORDS, k=random.randrange(3, 10)))
        ).capitalize()

    @staticmethod
    def filename(postfix=".txt"):
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

    @staticmethod
    def uuid():
        """Random uuid."""
        return uuid.uuid4()

    @staticmethod
    def ipv4():
        """Random uuid."""
        return ipaddress.IPv4Address(os.urandom(4))

    @staticmethod
    def new_secret() -> bytes:
        """Generate encryption key.

        Returns (bytes):
            Encryption key

        """
        return os.urandom(32)