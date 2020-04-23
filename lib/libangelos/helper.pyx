# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import asyncio
import datetime
import logging
import uuid

from libangelos.archive7 import Archive7
from libangelos.policy.portfolio import PortfolioPolicy
from libangelos.utils import Util


class Glue:
    @staticmethod
    def doc_save(document):
        """Calculates the correct meta information about a document to be updated

        Args:
            document (Document):
                Enter a valid Document.

        Returns (datetime.datetime, datetime.datetime, uuid.UUID):
            Correct meta-data (created datetime, touched datetime, owner).

        """
        return datetime.datetime.combine(
            document.created, datetime.datetime.min.time()), datetime.datetime.combine(
            document.get_touched(), datetime.datetime.min.time()), document.get_owner()

    @staticmethod
    def doc_check(datalist, _type, expiry_check=True):
        # validity = datetime.date.today() - datetime.timedelta(year=3)
        validity = datetime.date.today()
        doclist = []

        for data in datalist:
            doc = PortfolioPolicy.deserialize(data)
            if isinstance(doc, _type):
                # doc.validate()
                if expiry_check and doc.expires > validity:
                    doclist.append(doc)
                elif not expiry_check:
                    doclist.append(doc)

        return doclist

    @staticmethod
    def doc_validate(datalist, _type):
        doclist = []

        for data in datalist:
            try:
                doc = None
                doc = PortfolioPolicy.deserialize(data)
                Util.is_type(doc, _type)
                doc.validate()
                doclist.append(doc)
            except Exception as e:
                logging.error(e, exc_info=True)

        return doclist

    @staticmethod
    def doc_validate_report(datalist, _type, validate=True):
        doclist = []

        for data in datalist:
            try:
                doc = None
                doc = PortfolioPolicy.deserialize(data)
                Util.is_type(doc, _type)
                if validate:
                    doc.validate()
                doclist.append((doc, None))
            except Exception as e:
                logging.error(e, exc_info=True)
                doclist.append((doc if doc else data, str(e)))

        return doclist

    @staticmethod
    def run_async(*aws, raise_exc=True):
        loop = asyncio.get_event_loop()
        gathering = asyncio.gather(*aws, loop=loop, return_exceptions=True)
        loop.run_until_complete(gathering)

        result_list = gathering.result()
        exc = None
        for result in result_list:
            if isinstance(result, Exception):
                exc = result if not exc else exc
                logging.error("Operation failed: %s" % result)
        if exc:
            raise exc
        if len(result_list) > 1:
            return result_list
        else:
            return result_list[0]


class Globber:
    @staticmethod
    async def full(archive: Archive7, *args, **kwargs):
        return await archive.execute(Globber.__full, archive, *args, **kwargs)

    @staticmethod
    def __full(archive: Archive7, filename: str = "*", cmp_uuid: bool = False):
        sq = Archive7.Query(pattern=filename)
        sq.type(b"f")
        idxs = archive.ioc.entries.search(sq)
        ids = archive.ioc.hierarchy.ids

        files = {}
        for i in idxs:
            idx, entry = i
            if entry.__parent.int == 0:
                name = "/" + str(entry.name, "utf-8")
            else:
                name = ids[entry.__parent] + "/" + str(entry.name, "utf-8")
            if cmp_uuid:
                files[entry.id] = (name, entry.deleted, entry.modified)
            else:
                files[name] = (entry.id, entry.deleted, entry.modified)

        return files

    @staticmethod
    async def syncro(archive: Archive7, *args, **kwargs):
        return await archive.execute(Globber.__syncro, archive, *args, **kwargs)

    @staticmethod
    def __syncro(
            archive: Archive7,
            path: str = "/",
            owner: uuid.UUID = None,
            modified: datetime.datetime = None,
            cmp_uuid: bool = False,
    ):
        pid = archive.ioc.operations.get_pid(path)
        sq = Archive7.Query()
        sq.parent(pid)
        if owner:
            sq.owner(owner)
        if modified:
            sq.modified(modified)
        sq.type(b"f")
        idxs = archive.ioc.entries.search(sq)
        ids = archive.ioc.hierarchy.ids

        files = {}
        for i in idxs:
            idx, entry = i
            if entry.__parent.int == 0:
                name = "/" + str(entry.name, "utf-8")
            else:
                name = ids[entry.__parent] + "/" + str(entry.name, "utf-8")
            if cmp_uuid:
                files[entry.id] = (name, entry.modified, entry.deleted)
            else:
                files[name] = (entry.id, entry.modified, entry.deleted)

        return files

    @staticmethod
    async def owner(archive: Archive7, *args, **kwargs):
        return await archive.execute(Globber.__owner, archive, *args, **kwargs)

    @staticmethod
    def __owner(archive: Archive7, owner: uuid.UUID, path: str = "/"):
        sq = Archive7.Query(path).owner(owner).type(b"f")
        idxs = archive.ioc.entries.search(sq)
        ids = archive.ioc.hierarchy.ids

        files = []
        for i in idxs:
            idx, entry = i
            if entry.__parent.int == 0:
                name = "/" + str(entry.name, "utf-8")
            else:
                name = ids[entry.__parent] + "/" + str(entry.name, "utf-8")
            files.append((name, entry.id, entry.created))

        return files

    @staticmethod
    async def path(archive: Archive7, *args, **kwargs):
        return await archive.execute(Globber.__path, archive, *args, **kwargs)

    @staticmethod
    def __path(archive: Archive7, path: str = "*"):
        sq = Archive7.Query(path).type(b"f")
        idxs = archive.ioc.entries.search(sq)
        ids = archive.ioc.hierarchy.ids

        files = []
        for i in idxs:
            idx, entry = i
            if entry.__parent.int == 0:
                name = "/" + str(entry.name, "utf-8")
            else:
                name = ids[entry.__parent] + "/" + str(entry.name, "utf-8")
            files.append((name, entry.id, entry.created))

        return files
