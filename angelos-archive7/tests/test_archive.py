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
from collections import Counter
from pathlib import PurePosixPath, Path
from tempfile import TemporaryDirectory
from unittest.case import TestCase

from angelos.archive7.archive import Archive7, Header

from angelos.meta.testing import run_async
from angelos.meta.fake.lipsum import LIPSUM_PATH
from angelos.meta.fake import Generate


class TestArchive7(TestCase):
    FILE_COUNT = 128
    # TODO: Make archive7 stable with thousands of files.

    @classmethod
    def setUpClass(cls) -> None:
        """Prepare class-wise environment"""
        random.seed(0)
        cls.dir = TemporaryDirectory()
        cls.secret = os.urandom(32)
        cls.filename = Path(cls.dir.name, "test.ar7")
        if cls.filename.exists():
            raise OSError("File shouldn't be there.")
        cls.owner = Generate.uuid()
        cls.archive = Archive7.setup(cls.filename, cls.secret, owner=cls.owner)
        cls.files = dict()
        cls.links = dict()
        for _ in range(cls.FILE_COUNT):
            filename = PurePosixPath(random.choice(LIPSUM_PATH), Generate.filename())
            cls.files[filename] = Generate.lipsum()
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
                await self.archive.mkdir(PurePosixPath(path))
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
                self.files[PurePosixPath(filename.parent, name)] = self.files[filename]
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
                dirs.remove(str(filename.parent))
                dirname = PurePosixPath(random.choice(dirs))
                await self.archive.move(filename, dirname)
                self.files[PurePosixPath(dirname, filename.parts[-1])] = self.files[filename]
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
                result = await self.archive.isdir(PurePosixPath(path))
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
                result = await self.archive.isfile(PurePosixPath(path))
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
                linkname = PurePosixPath(random.choice(LIPSUM_PATH), Generate.filename())
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
            total = set([PurePosixPath(path) for path in LIPSUM_PATH] + [PurePosixPath("/")] + files + links)
            self.assertEqual(Counter(globed), Counter(total))
        except Exception as e:
            self.fail(e)
