"""ar7 is a utility to work with Archive7/ConcealIO encrypted archives."""
import os
import getpass

from angelos.archive.archive7 import Archive7, Entry


def get_key(args):
    """Receive encryption key if --key argument not set."""
    msg = 'Archives are encrypted and a key is ' \
          'required in order to deal with them.'
    if args.key:
        return args.key.encode('utf-8')
    else:
        print(msg)
        key = getpass.getpass('Encryption key: ')
        return key.encode('utf-8')


def run_test(args, parser):
    """Run command test."""
    src = args.test
    key = get_key(args)

    try:
        with Archive7.open(src, key) as arch, arch.lock:
            valid = True
            ops = arch.ioc.operations
            entries = arch.ioc.entries
            ids = arch.ioc.hierarchy.ids

            idxs = entries.search(
                Archive7.Query().type(Entry.TYPE_FILE).deleted(True),
                True)

            for i in idxs:
                idx, entry = i
                if entry.parent.int == 0:
                    filename = '/'+str(entry.name, 'utf-8')
                else:
                    filename = ids[entry.parent]+'/'+str(
                        entry.name, 'utf-8')

                data = ops.load_data(entry)
                if entry.compression:
                    data = ops.unzip(data, entry.compression)

                if ops.check(entry, data):
                    valid = False
                    if args.verbose:
                        print('Corrupt file: %s, %s' % (
                            entry.id, filename))

            print('Archive status: %s' % ('OK' if valid else 'Corrupt'))

    except Exception as e:
        parser.exit(1, 'Archive status: %s, %s' % ('Broken', e))


def run_list(args, parser):
    """Run command list."""
    src = args.list
    key = get_key(args)

    try:
        with Archive7.open(src, key) as arch, arch.lock:
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
                elif entry.tyoe == Entry.TYPE_DIR:
                    dirs += 1
                elif entry.type == Entry.TYPE_LINK:
                    links += 1

                print(filename)

            print('Statistics:\nFiles: %s\nDirs: %s\nLinks: %s\nSpace: %s' % (
                files, dirs, links, size))

    except Exception as e:
        parser.exit(1, 'Archive status: %s, %s' % ('Broken', e))


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

    try:
        with Archive7.open(src, key) as arch, arch.lock:
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

                realname = os.path.join(curdir, filename)
                if entry.type == Entry.TYPE_DIR:
                    os.mkdir(realname)
                elif entry.type == Entry.TYPE_FILE:
                    os.makedirs(os.dirname(realname), exist_ok=True)

                    data = ops.load_data(entry)
                    if entry.compression:
                        data = ops.unzip(data, entry.compression)

                    if ops.check(entry, data):
                        if args.verbose:
                            print('Corrupt file: %s, %s' % (
                                entry.id, filename))
                        raise OSError('Corrupt file: %s, %s' % (
                            entry.id, filename))

                    with open(realname, 'xb') as outfile:
                        outfile.write(arch.load(filename))

    except Exception as e:
        parser.exit(1, 'Something went wrong: %s' % e)


def main():
    """Ar7 utility main method."""
    import argparse

    description = \
        'Archive7/ConcealIO encrypted and ' \
        'compressed archive commandline utility.'
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument('-v', '--verbose', action='store_true', default=False,
                        help='Verbose output')
    parser.add_argument('-k', '--key', action='store_true', default=False,
                        type=lambda x: x.encode('utf-8'),
                        help='Encryption key')
    parser.add_argument('-z', '--zip', action='store_true', default=False,
                        help='Use compression')

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

    if args.test is not None:
        run_test(args, parser)
    elif args.list is not None:
        run_list(args, parser)
    elif args.extract is not None:
        run_extract(args, parser)
    elif args.create is not None:
        filename = args.create.pop(0)


if __name__ == '__main__':
    main()
