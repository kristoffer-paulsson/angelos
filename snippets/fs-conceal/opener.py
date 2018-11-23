"""Defines the S3FSOpener."""

__all__ = ['ConcealFSOpener']

from fs.opener import Opener, OpenerError

from ._s3fs import S3FS


class ConcealFSOpener(Opener):
    protocols = ['hide', 'conceal']

    def open_fs(self, fs_url, parse_result, writeable, create, cwd):
        key, _, dir_path = parse_result.resource.partition('/')
        if not key:
            raise OpenerError(
                "invalid key in '{}'".format(fs_url)
            )
        concealfs = S3FS(
            key,
            dir_path=dir_path or '/',
        )
        return concealfs
