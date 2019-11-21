"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import sys
sys.path.append('../angelos')  # noqa

import unittest
import tempfile
import shutil
import os
import random
import uuid
import logging
import datetime

import libnacl.secret

from lipsum import LIPSUM_PATH
from support import generate_data, generate_filename
from angelos.archive.archive7 import Archive7
from angelos.archive.replicator import Replicator


FILES = [
    '/fish/salmon/axgsu2w7.txt',
    '/animal/horse/jgp2ap.txt',
    '/animal/bear/jawmi.txt',
    '/livestock/goat/y7d0uv4c8.txt',
    '/pet/hamster/empt17v0n.txt',
    '/predator/alligator/5n58rr19.txt',
    '/animal/bear/slnv2.txt',
    '/pet/hamster/l3n39ksm7.txt',
    '/livestock/pig/wmic0a9.txt',
    '/animal/horse/f9exuci6n.txt',
    '/animal/zaca6wy.txt',
    '/fish/guppy/uv1ai2d7.txt',
    '/fish/salmon/i2wyd3.txt',
    '/predator/uwr6q10k.txt',
    '/rodent/squirrel/z0k2z5.txt',
    '/livestock/chicken/x1uy3c9tz.txt',
    '/animal/elephant/jb9hsrnng.txt',
    '/enauh4x.txt',
    '/animal/hippo/jstz553t.txt',
    '/fish/guppy/y0a5u1.txt',
    '/pet/hamster/uinle2pj5.txt',
    '/animal/girafe/qre5hr.txt',
    '/animal/elephant/lu2gan.txt',
    '/fish/eel/mbapl.txt',
    '/livestock/goat/pvkyoq2eo.txt',
    '/fish/guppy/n1yol.txt',
    '/animal/horse/wnuw20g5.txt',
    '/predator/killerwhale/xnvo6.txt',
    '/animal/horse/mwokfyhxl.txt',
    '/livestock/sheep/qfc8c.txt',
    '/rodent/l45i8d1.txt',
    '/rodent/rat/ero4jfn.txt',
    '/predator/lion/9o5l3s9.txt',
    '/livestock/sheep/8u5mi2mz.txt',
    '/pet/dog/vawjouvu.txt',
    '/pet/hamster/zbm2f.txt',
    '/fish/herring/1wpry.txt',
    '/animal/hippo/r96nlz4h.txt',
    '/livestock/goat/o11mzkdud.txt',
    '/pet/cat/1an03d.txt',
    '/pet/5v38q25g.txt',
    '/livestock/cow/bwpq5hj9.txt',
    '/fish/guppy/sqcequ1r.txt',
    '/fish/eel/jwczq.txt',
    '/predator/qkfpc.txt',
    '/rodent/squirrel/1alfu8bzo.txt',
    '/livestock/sheep/52nsodi.txt',
    '/rodent/3ws68x.txt',
    '/rodent/squirrel/cgp54jw.txt',
    '/pet/parrot/3f7p0.txt',
    '/livestock/cow/4rv5gq.txt',
    '/pet/parrot/qrhz6.txt',
    '/animal/2o6q0.txt',
    '/predator/0r0rzeq.txt',
    '/rodent/mouse/gxjzuv.txt',
    '/livestock/cow/sym6bav.txt',
    '/livestock/sheep/svk96.txt',
    '/c5bren.txt',
    '/pet/dog/890rggp58.txt',
    '/qebdh8s4.txt',
    '/rodent/lemming/k1efkr8o.txt',
    '/animal/bplvc4.txt',
    '/livestock/pig/jw4kg25.txt',
    '/animal/894ulng6k.txt',
    '/pet/bunny/d49asvk7.txt',
    '/pet/parrot/97wq6.txt',
    '/pet/bunny/gsah8uyms.txt',
    '/fish/v8a1y.txt',
    '/livestock/pig/brgo891.txt',
    '/fish/guppy/x6dnaz.txt',
    '/animal/rhino/xtzm9v.txt',
    '/predator/lion/xa73slfv.txt',
    '/livestock/sheep/4zhxewc.txt',
    '/predator/lion/cn7pyffkb.txt',
    '/rodent/lemming/19pcitpgq.txt',
    '/pet/tpmq5c.txt',
    '/fish/salmon/8tqhm54o.txt',
    '/animal/304o20ya.txt',
    '/animal/hippo/6kxdv1q.txt',
    '/fish/herring/gosv214.txt',
    '/pet/qt4tki69o.txt',
    '/pet/parrot/gsvhsf4.txt',
    '/livestock/sheep/8kpncds.txt',
    '/fish/eel/105lqrah.txt',
    '/pet/hamster/jndhmy.txt',
    '/animal/rhino/frctz.txt',
    '/predator/alligator/w56jmr1sm.txt',
    '/rodent/rat/66uqs3k.txt',
    '/livestock/sheep/b4tx8i5.txt',
    '/predator/ca156lzu.txt',
    '/animal/9vy0ka51b.txt',
    '/animal/elephant/bl5s6e.txt',
    '/fish/herring/1e0d5h7ef.txt',
    '/pet/bunny/16p3p.txt',
    '/fish/eel/i27amko.txt',
    '/rodent/leo6ok.txt',
    '/mrj6983.txt',
    '/predator/wolf/aewqw32wg.txt',
    '/rodent/lemming/ip49ww1z.txt',
    '/pet/hamster/mnrt3wd4.txt',
    '/predator/wolf/zgatr5jq.txt',
    '/rodent/5sm5l5.txt',
    '/pet/parrot/c649exf.txt',
    '/livestock/pig/rd7g4p.txt',
    '/rodent/lemming/hkj0c2zsn.txt',
    '/predator/alligator/e4ajk.txt',
    '/livestock/wdpn4bf.txt',
    '/rodent/rat/m1n933.txt',
    '/mg83fb.txt',
    '/livestock/chicken/4q1tn.txt'
]


class TestReplication(unittest.TestCase):
    @classmethod
    def setUp(self):
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
        self.secret = libnacl.secret.SecretBox().sk
        self.dir = tempfile.TemporaryDirectory()
        self.filename = os.path.join(self.dir.name, 'test.ar7.cnl')
        self.replica = os.path.join(self.dir.name, 'copy.ar7.cnl')
        self.owner = uuid.uuid4()

        now = datetime.datetime.now()
        before = now - datetime.timedelta(1)

        with Archive7.setup(
                self.filename, self.secret, owner=self.owner) as arch:

            for dir in LIPSUM_PATH:
                arch.mkdir(dir)

            for filename in FILES:
                data = generate_data()
                arch.mkfile(filename, data, created=before, modified=before)

        shutil.copy(self.filename, self.replica)

        with Archive7.open(
                self.filename, self.secret, Archive7.Delete.HARD) as arch:

            random.shuffle(FILES)
            for filename in FILES[:20]:
                info = arch.info(filename)
                data = generate_data()
                arch.remove(filename)
                arch.mkfile(filename, data,
                            created=before, modified=now, id=info.id)

            random.shuffle(FILES)
            for filename in FILES[:20]:
                arch.remove(filename)

            for i in range(20):
                data = generate_data()
                filename = random.choices(
                    LIPSUM_PATH, k=1)[0] + '/' + generate_filename()
                arch.mkfile(filename, data, created=before, modified=before)

        with Archive7.open(
                self.replica, self.secret, Archive7.Delete.HARD) as arch:

            random.shuffle(FILES)
            for filename in FILES[:20]:
                info = arch.info(filename)
                data = generate_data()
                arch.remove(filename, Archive7.Delete.ERASE)
                arch.mkfile(filename, data,
                            created=before, modified=now, id=info.id)

            random.shuffle(FILES)
            for filename in FILES[:20]:
                arch.remove(filename)

            for i in range(20):
                data = generate_data()
                filename = random.choices(
                    LIPSUM_PATH, k=1)[0] + '/' + generate_filename()
                arch.mkfile(filename, data, created=before, modified=before)

    @classmethod
    def tearDown(self):
        self.dir.cleanup()

    def test_replicate(self):
        """Creating new empty archive"""
        logging.info('====== %s ======' % 'test_replicate')
        master = Archive7.open(
            self.filename, self.secret, Archive7.Delete.HARD)
        slave = Archive7.open(
            self.replica, self.secret, Archive7.Delete.HARD)
        Replicator.synchronize(master, slave)


if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'])
