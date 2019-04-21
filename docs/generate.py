import sys
import subprocess
from setuptools import find_packages
from pkgutil import iter_modules


def find_modules(path):
    modules = set()
    for pkg in find_packages(path):
        modules.add(pkg)
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


def find_module_paths(path):
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

    paths = []
    aliases = []
    for m in modules:
        a = m.replace('.', '_')
        m = m.replace('.', '/')
        m += '.py'
        paths.append(m)
        aliases.append(a)
    return paths, aliases


def main():
    modules = ['angelos.py']
    mods, aliases = find_module_paths('.')
    modules += mods
    modules = [k for k in modules if 'angelos' in k]
    aliases = [k for k in aliases if 'angelos' in k]
    print(sorted(modules), sorted(aliases))
    # for path in modules:
    #    print(path)
    #    subprocess.run(['pydoc', '-w', path])


if __name__ == "__main__":
    main()
