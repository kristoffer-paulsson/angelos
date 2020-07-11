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
import copy
import os
import random
from tempfile import TemporaryDirectory
from unittest.case import TestCase

from libangelos.archive7.archive import Archive7, Header

from tests.support.lipsum import LIPSUM_PATH
from tests.support.generate import run_async, Generate


class TestArchive7(TestCase):
    FILE_COUNT = 128
    # TODO: Make archive7 stable with thousands of files.

    @classmethod
    def setUpClass(cls) -> None:
        """Prepare class-wise environment"""
        random.seed(0)
        cls.dir = TemporaryDirectory()
        cls.secret = os.urandom(32)
        cls.filename = os.path.join(cls.dir.name, "test.ar7")
        if os.path.exists(cls.filename):
            raise OSError("File shouldn't be there.")
        cls.owner = Generate.uuid()
        cls.archive = Archive7.setup(cls.filename, cls.secret, owner=cls.owner)
        cls.files = dict()
        cls.links = dict()
        for _ in range(cls.FILE_COUNT):
            cls.files[os.path.join(random.choice(LIPSUM_PATH), Generate.filename())] = Generate.lipsum()
        cls.archive.close()

    @classmethod
    def tearDownClass(cls) -> None:
        """Cleanup class-wise environment"""
        cls.archive.close()
        os.unlink(cls.filename)
        cls.dir.cleanup()

    def setUp(self) -> None:
        """Setup a file archive environment."""
        self.archive = Archive7.open(self.filename, self.secret)

    def tearDown(self) -> None:
        """Cleanup a file archive environment."""
        self.archive.close()

    def test_setup(self):
        """Archive is setup initially."""
        pass

    def test_open(self):
        """Archive is opened for each test."""
        pass

    def test_closed(self):
        """Archive is closed for each test."""
        pass

    def test_close(self):
        """Archive is closed for each test."""
        pass

    def test_search(self):
        """Already tested via teh glob test."""
        pass

    def test_stats(self):
        try:
            header = self.archive.stats()
            self.assertIsInstance(header, Header)
            self.assertEqual(header.owner, self.owner)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_01_mkdir(self):
        try:
            for path in LIPSUM_PATH:
                await self.archive.mkdir(path)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_02_mkfile(self):
        try:
            for filename in self.files.keys():
                await self.archive.mkfile(filename=filename, data=self.files[filename])
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_03_rename(self):
        try:
            keys = list(self.files.keys())
            random.shuffle(keys)
            for filename in keys[:self.FILE_COUNT // 4]:
                name = Generate.filename()
                await self.archive.rename(filename, name)
                self.files[os.path.join(os.path.dirname(filename), name)] = self.files[filename]
                del self.files[filename]
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_04_move(self):
        try:
            keys = list(self.files.keys())
            random.shuffle(keys)
            for filename in keys[:self.FILE_COUNT // 4]:
                dirs = copy.deepcopy(LIPSUM_PATH)
                dirs.remove(os.path.dirname(filename))
                dirname = random.choice(dirs)
                await self.archive.move(filename, dirname)
                self.files[os.path.join(dirname, os.path.basename(filename))] = self.files[filename]
                del self.files[filename]
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_05_save(self):
        try:
            keys = list(self.files.keys())
            random.shuffle(keys)
            for filename in keys[:self.FILE_COUNT // 4]:
                text = Generate.lipsum()
                await self.archive.save(filename, text)
                self.files[filename] = text
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_06_load(self):
        try:
            for filename in self.files.keys():
                data = await self.archive.load(filename)
                self.assertEqual(self.files[filename], data)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_07_chmod(self):
        try:
            for filename in self.files.keys():
                await self.archive.chmod(filename, user="tester", group="tester")
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_08_info(self):
        try:
            for filename in self.files.keys():
                entry = await self.archive.info(filename)
                self.assertEqual(entry.user, b"tester")
                self.assertEqual(entry.group, b"tester")
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_09_isdir(self):
        try:
            for path in LIPSUM_PATH:
                result = await self.archive.isdir(path)
                self.assertTrue(result)

            for filename in self.files.keys():
                result = await self.archive.isdir(filename)
                self.assertFalse(result)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_10_isfile(self):
        try:
            for path in LIPSUM_PATH:
                result = await self.archive.isfile(path)
                self.assertFalse(result)

            for filename in self.files.keys():
                result = await self.archive.isfile(filename)
                self.assertTrue(result)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_11_remove(self):
        try:
            keys = list(self.files.keys())
            random.shuffle(keys)
            for filename in keys[:self.FILE_COUNT // 4]:
                await self.archive.remove(filename)
                del self.files[filename]
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_12_link(self):
        try:
            keys = list(self.files.keys())
            random.shuffle(keys)
            for filename in keys[:self.FILE_COUNT // 4]:
                linkname = os.path.join(random.choice(LIPSUM_PATH), Generate.filename())
                await self.archive.link(linkname, filename)
                self.links[linkname] = self.files[filename]
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_13_islink(self):
        try:
            for filename in self.files.keys():
                result = await self.archive.islink(filename)
                self.assertFalse(result)

            for linkname in self.links.keys():
                result = await self.archive.islink(linkname)
                self.assertTrue(result)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_14_glob(self):
        try:
            globed = await self.archive.glob()
            files = list(self.files.keys())
            links = list(self.links.keys())
            total = set(LIPSUM_PATH + ["/"] + files + links)
            # print(
            #    len(LIPSUM_PATH),
            #    len(globed),
            #    len(files),
            #    len(links),
            #    len(files + links),
            #    len(LIPSUM_PATH + ["/"] + files + links)
            # )

            # print(globed - total)
            # print(total - globed)
            self.assertEqual(globed, total)
        except Exception as e:
            self.fail(e)