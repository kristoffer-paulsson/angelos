import logging
import sys
import tracemalloc
from pathlib import Path
from unittest import TestCase


class TestPackage(TestCase):

    @classmethod
    def setUpClass(cls) -> None:
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.INFO)

    def iterator(self, namespace):
        ns_path = Path("./").resolve()
        ns_parts_cnt = len(ns_path.parts)
        for pkg_path in ns_path.rglob(namespace + "-*/src/"):
            for mod_path in pkg_path.rglob("*.pyx"):
                yield (pkg_path.parts[-2:-1][0], ".".join(mod_path.parts[ns_parts_cnt+2:-1] + (mod_path.stem,)), str(mod_path))

    def test_glob(self):
        for result in self.iterator("angelos"):
            logging.INFO(result)

