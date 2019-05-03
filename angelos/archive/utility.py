"""Archive7 utility code."""
import os
import sys
import re
import pwd
import grp
import uuid
import getpass
import glob
import binascii
import logging
import hashlib
import math
import pathlib

import libnacl

from .archive7 import Archive7, Entry


BYTES_SUF = ('B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB')
ENDING_SUF = '.ar7.cnl'


def out(*args):
    """Stream wrapper for sys.stdout."""
    sys.stdout.write(' '.join([str(s) for s in args]) + '\n')


def err(*args):
    """Stream wrapper for sys.stderr."""
    sys.stderr.write(' '.join([str(s) for s in args]) + '\n')


def get_key(args, generate=False):
    """Receive encryption key if --key argument not set."""
    msg = '\nArchives are encrypted, a key is ' \
          'necessary in order to work with them.'
    if args.key:
        if re.match('^[0-9a-f-A-F]{64}$', args.key):
            return binascii.unhexlify(args.key)
        else:
            return binascii.unhexlify(
                hashlib.sha512(args.key.encode()).hexdigest()[64:])

    else:
        out(msg)
        key = getpass.getpass(
            'Encryption key or password%s: ' % (
                ' (leave blank for autogen)' if generate else '')
            ).encode('utf-8')

    if re.match('^[0-9a-f-A-F]{64}$', key.decode()):
        return binascii.unhexlify(key)
    elif len(key) == 0 and generate:
        out('\nGenerate encryption key!\n')
        key = libnacl.secret.SecretBox().sk
        out('The new encryption key is:\n' +
            '\033[32m%s\033[0m\n(\033[36;5mMake a backup!\033[0m)\n' % (
                  binascii.hexlify(key).decode()))
        return key
    else:
        out('\nAssume it\'s a password. ' +
            '(\033[33;5mWeak cryptography!!!\033[0m)\n')
        return binascii.unhexlify(hashlib.sha512(key).hexdigest()[64:])


def file_size(size):
    """Human readable filesize."""
    order = int(math.log2(size) / 10) if size else 0
    return '{:<5.4g} {:}'.format(size / (1 << (order * 10)), BYTES_SUF[order])


def run_test(args, parser):
    """Run command test."""
    src = args.test
    key = get_key(args)
    corruption = []
    valid = True

    with Archive7.open(src, key, mode='rb') as arch, arch.lock:
        ops = arch.ioc.operations
        entries = arch.ioc.entries
        ids = arch.ioc.hierarchy.ids

        idxs = entries.search(
            Archive7.Query().type(Entry.TYPE_FILE).deleted(False), True)

        for i in idxs:
            idx, entry = i
            if entry.parent.int == 0:
                filename = '/'+str(entry.name, 'utf-8')
            else:
                filename = ids[entry.parent]+'/'+str(
                    entry.name, 'utf-8')

            data = ops.load_data(entry)
            cur_valid = True
            if entry.compression:
                try:
                    data = ops.unzip(data, entry.compression)
                except OSError as e:
                    corruption.append((str(e) + ', could not decompress', ))

            if not ops.check(entry, data):
                valid = False
                cur_valid = False
                corruption.append(('Invalid signature, digest mismatch', ))

            if args.verbose:
                out('{v:13}  {3:}  {0:<6}{2:<10}  {1:}'.format(
                    '0{:o}'.format(entry.perms) if entry.perms else 'n/a ',
                    filename,
                    file_size(entry.length) if entry.length else ' ',
                    entry.type.decode().upper(), v=('\033[32mOK\033[0m' if (
                        cur_valid) else '\033[31mFAIL\033[0m')))
            elif not args.quite:
                out('{:4} {:}'.format(
                    'OK' if (cur_valid) else 'FAIL', filename))

            if args.verbose and not cur_valid:
                for p in corruption:
                    err('Error:\033[33m', *p, '\033[33;0m')
                err('')

            corruption = []

    if args.verbose:
        out('Archive status: %s\n' % (
            '\033[32mOK\033[0m' if valid else '\033[31mCorrupt\033[0m'))
    elif not args.quite:
        out('Archive status: %s\n' % (
            'OK' if valid else 'Corrupt'))

    if args.quite:
        if valid:
            parser.exit(0)
        else:
            parser.exit(1)


def run_list(args, parser):
    """Run command list."""
    src = args.list
    key = get_key(args)

    # try:
    with Archive7.open(src, key, mode='rb') as arch, arch.lock:
        entries = arch.ioc.entries
        ids = arch.ioc.hierarchy.ids

        idxs = entries.search(Archive7.Query(), True)

        files = 0
        dirs = 0
        links = 0
        size = 0
        for i in idxs:
            idx, entry = i

            if entry.type in [Entry.TYPE_BLANK, Entry.TYPE_EMPTY]:
                continue

            if entry.parent.int == 0:
                filename = '/'+str(entry.name, 'utf-8')
            else:
                filename = ids[entry.parent]+'/'+str(
                    entry.name, 'utf-8')

            if entry.type == Entry.TYPE_FILE:
                files += 1
                size += entry.length
            elif entry.type == Entry.TYPE_DIR:
                dirs += 1
            elif entry.type == Entry.TYPE_LINK:
                links += 1

            if args.verbose:
                out('{3:}  {0:<6}{2:<9}  {1:}'.format(
                    '0{:o}'.format(entry.perms) if entry.perms else 'n/a ',
                    filename,
                    file_size(entry.length) if entry.length else ' ',
                    entry.type.decode().upper()))
            else:
                out(filename)

        if args.verbose:
            out(
                'Statistics:\nFiles: %s\nDirs: %s\nLinks: %s\nSpace: %s\n' % (
                    files, dirs, links, size))


def run_extract(args, parser):
    """Run command extract."""
    if len(args.extract) == 1:
        src = args.extract[0]
        curdir = os.curdir
    elif len(args.extract) == 2:
        src, curdir = args.extract
    else:
        parser.exit(1, parser.format_help())

    key = get_key(args)
    corruption = []
    valid = True

    with Archive7.open(src, key, mode='rb') as arch, arch.lock:
        entries = arch.ioc.entries
        ids = arch.ioc.hierarchy.ids
        ops = arch.ioc.operations

        idxs = entries.search(Archive7.Query(), True)

        for i in idxs:
            idx, entry = i

            if entry.type in [Entry.TYPE_BLANK, Entry.TYPE_EMPTY]:
                continue

            if entry.parent.int == 0:
                filename = '/'+str(entry.name, 'utf-8')
            else:
                filename = ids[entry.parent]+'/'+str(
                    entry.name, 'utf-8')

            realname = os.path.join(curdir, filename[1:])

            if entry.type == Entry.TYPE_DIR:
                try:
                    dirname = realname
                    if not os.path.isdir(dirname):
                        os.makedirs(dirname, exist_ok=True)
                except OSError as e:
                    corruption.append(
                        (str(e) + ', failed creating directory', ))

            elif entry.type == Entry.TYPE_FILE:
                try:
                    dirname = os.path.dirname(realname)
                    if not os.path.isdir(dirname):
                        os.makedirs(dirname, exist_ok=True)
                except OSError as e:
                    corruption.append(
                        (str(e) + ', failed creating directory', ))

                data = ops.load_data(entry)
                if entry.compression:
                    try:
                        data = ops.unzip(data, entry.compression)
                    except OSError as e:
                        corruption.append(
                            (str(e) + ', could not decompress', ))

                if not ops.check(entry, data):
                    corruption.append(('Invalid signature, digest mismatch', ))

                try:
                    if not corruption:
                        if os.path.isfile(realname) and not args.force:
                            raise OSError('File already exists')
                        with open(realname, 'wb') as outfile:
                            if args.force:
                                outfile.seek(0)
                                outfile.truncate()
                            outfile.write(data)
                except OSError as e:
                    corruption.append((str(e), ))

                if corruption:
                    valid = False

            elif entry.type == Entry.TYPE_LINK:
                continue

            if args.verbose:
                out('{v:13}  {3:}  {0:<6}{2:<10}  {1:}'.format(
                    '0{:o}'.format(entry.perms) if entry.perms else 'n/a ',
                    filename,
                    file_size(entry.length) if entry.length else ' ',
                    entry.type.decode().upper(), v=('\033[32mOK\033[0m' if (
                        not corruption) else '\033[31mFAIL\033[0m')))
            elif not args.quite:
                out('{:4} {:}'.format(
                    'OK' if not corruption else 'FAIL', filename))

            if args.verbose and corruption:
                for p in corruption:
                    err('Error:\033[33m', *p, '\033[33;0m')
                err('')

            corruption = []

    if args.verbose:
        out('Archive status: %s\n' % (
            '\033[32mOK\033[0m' if valid else '\033[31mCorrupt\033[0m'))
    elif not args.quite:
        out('Archive status: %s\n' % (
            'OK' if valid else 'Corrupt'))

    if args.quite:
        if valid:
            parser.exit(0)
        else:
            parser.exit(1)


def run_create(args, parser):
    """Run command extract."""
    archive = args.create.pop(0)

    if os.path.exists(archive):
        parser.exit(1, 'File %s already exists.\n' % archive)

    key = get_key(args, True)

    if args.zip:
        compression = Entry.COMP_BZIP2
    else:
        compression = Entry.COMP_NONE

    suflen = len(archive) - len(''.join(pathlib.Path(archive).suffixes))
    archive = archive[:suflen] + ENDING_SUF

    with Archive7.setup(archive, key, uuid.UUID(int=0)) as arch:
        for source in args.create:
            if os.path.isfile(source):
                dirname, name = os.path.split(source)
                parent = arch.mkdir(dirname)
                with open(source) as f:
                    arch.mkfile(name, f.read(), parent=parent)

            elif os.path.isdir(source):
                for filename in glob.iglob(
                        os.path.join(source, '**/*'), recursive=True):

                    if args.unix:
                        stat_info = os.stat(filename)
                        perms = stat_info.st_mode & 0o777
                        user = pwd.getpwuid(stat_info.st_uid)[0]
                        group = grp.getgrgid(stat_info.st_gid)[0]
                    else:
                        perms = None
                        user = None
                        group = None

                    if os.path.isfile(filename):
                        fullname = '/' + os.path.relpath(filename, source)
                        if not args.quite:
                            out(fullname)
                        elif args.verbose:
                            out('F {0:o}, {1:}'.format(perms, fullname))
                        dirname, name = os.path.split(fullname)
                        parent = arch.mkdir(dirname)
                        with open(filename, 'rb') as f:
                            arch.mkfile(
                                name, f.read(), parent=parent,
                                user=user, group=group, perms=perms,
                                compression=compression)

                    elif os.path.isdir(filename):
                        dirname = '/' + os.path.relpath(filename, source)
                        if not args.quite:
                            out(dirname)
                        elif args.verbose:
                            out('D {0:o}, {1:}'.format(perms, dirname))
                        try:
                            arch.mkdir(
                                dirname, user=user,
                                group=group, perms=perms)
                        except RuntimeError:
                            arch.chmod(
                                dirname, user=user,
                                group=group, permsissions=perms)

            else:
                raise OSError(
                    '%s is not a valid file or directory' % source)

    if args.verbose:
        out('\nThe encryption key is:\n' +
            '\033[32m%s\033[0m\n(\033[36;5mMake a backup!\033[0m)\n' % (
                binascii.hexlify(key).decode()))


def main():
    """Ar7 utility main method."""
    import argparse

    description = \
        'Archive7/ConcealIO encrypted and ' \
        'compressed archive commandline utility.'

    parser = argparse.ArgumentParser(description=description)
    parser.add_argument('-k', '--key', metavar='<key>', default=False,
                        help='Encryption key')
    parser.add_argument('-z', '--zip', action='store_true', default=False,
                        help='Use compression')
    parser.add_argument('-u', '--unix', action='store_true', default=False,
                        help='Regard Unix ownership and permissions')
    parser.add_argument('-q', '--quite', action='store_true', default=False,
                        help='Silence all output')
    parser.add_argument('-f', '--force', action='store_true', default=False,
                        help='Force extration if file exists')
    parser.add_argument('-v', '--verbose', action='store_true', default=False,
                        help='Verbose output')

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('-l', '--list', metavar='<archive>',
                       help='Show listing of an archive')
    group.add_argument('-e', '--extract', nargs='+',
                       metavar=('<archive>', '<output_dir>'),
                       help='Extract archive into target dir')
    group.add_argument('-c', '--create', nargs='+',
                       metavar=('<name>', '<file>'),
                       help='Create archive from sources')
    group.add_argument('-t', '--test', metavar='<archive>',
                       help='Test if a archive is valid')

    args = parser.parse_args()

    if args.zip and not args.create:
        parser.error('-z/--zip can only be used with -c/--create.')
    if args.unix and not (args.create or args.extract):
        parser.error('-u/--unix can only be used ' +
                     'with -c/--create or -e/--extract.')
    if args.quite and not args.key:
        parser.error('-f/--force can only be used with -e/--extract.')
    if args.verbose and args.quite:
        parser.error('-v/--verbose can not be used with -q/--quite.')
    if args.quite and not args.key:
        parser.error('-k/--key MUST be used with -q/--quite.')

    try:
        if args.test is not None:
            run_test(args, parser)
        elif args.list is not None:
            run_list(args, parser)
        elif args.extract is not None:
            run_extract(args, parser)
        elif args.create is not None:
            run_create(args, parser)

    except (binascii.Error, ValueError) as e:
        if args.verbose:
            err('-' * 20, 'Verbose info start', '-' * 20)
            logging.exception(e)
            err('-' * 21, 'Verbose info end', '-' * 21)
        if not args.quite:
            parser.exit(1, 'Program exited bacause of: %s.\n\n' % e)
        else:
            parser.exit(1)

    except Exception as e:
        if not args.quite:
            err('-' * 20, '\033[33mCrash report start\033[0m', '-' * 20)
            logging.exception(e)
            err('-' * 21, '\033[33mCrash report end\033[0m', '-' * 21)
            parser.exit(2)

    parser.exit(0)
