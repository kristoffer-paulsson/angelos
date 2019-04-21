"""
modules.py will scan a folder for all python modules and according to a filter.

modules take two arguments:
path (-p) which is the path to scan through. If not given defaults to '.'
pkg (-m) is the package to not filter out.

The result is returned in stdout.
"""
import argparse
import sys
from setuptools import find_packages
from pkgutil import iter_modules


def parser():
    """Return the argument parser."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-p', '--path', dest='path',
        default='.', help='Which path to look for packages.')
    parser.add_argument(
        '-m', '--pkg', dest='pkg',
        default=False, help='Filter out a certian package.')
    return parser


def find(path):
    """Find all python modules in any subpackages."""
    modules = set()
    for pkg in find_packages(path):
        # modules.add(pkg)
        pkgpath = path + '/' + pkg.replace('.', '/')
        if sys.version_info.major == 2 or (
                sys.version_info.major == 3 and sys.version_info.minor < 6):
            for _, name, ispkg in iter_modules([pkgpath]):
                if not ispkg:
                    modules.add(pkg + '.' + name)
        else:
            for info in iter_modules([pkgpath]):
                if not info.ispkg:
                    modules.add(pkg + '.' + info.name)
    return modules


def main():
    """Execute the search for python modules."""
    args = parser().parse_args()

    modules = find(args.path)
    if args.pkg:
        modules = [k for k in modules if args.pkg in k]
    modules = sorted(modules)

    files = []
    for m in modules:
        m = m.replace('.', '/')
        m += '.py'
        files.append(m)

    return ' '.join(files)


if __name__ == '__main__':
    sys.stdout.write(main())
