import datetime

from ..utils import Util
from .archive7 import Archive7


class Glue:
    @staticmethod
    def doc_save(document):
        try:
            owner = document.owner
        except AttributeError:
            owner = document.issuer

        try:
            updated = datetime.datetime.combine(
                document.updated, datetime.datetime.min.time())
        except (AttributeError, TypeError):
            updated = None

        created = datetime.datetime.combine(
            document.created, datetime.datetime.min.time())

        return created, updated, owner


class Globber:
    @staticmethod
    def full(archive):
        Util.is_type(archive, Archive7)
