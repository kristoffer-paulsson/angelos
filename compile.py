"""Extension compile setup."""
import sys
from setuptools import setup
from distutils.extension import Extension
from Cython.Build import cythonize
from Cython.Distutils import build_ext


def build_libar7():
    """Build libar7."""
    setup(
        install_requires=[
            'libnacl',
        ],
        ext_modules=cythonize([
            Extension('libar7', ['libar7.c'])
        ]),
        cmdclass={'build_ext': build_ext}
    )


def build_libeidon():
    """Build libeidon."""
    setup(
        install_requires=[],
        ext_modules=cythonize([
            Extension('eidon', ['eidon.c']),
        ]),
        cmdclass={'build_ext': build_ext}
    )


def build_libangelos():
    """Build libangelos."""
    setup(
        install_requires=[
            'asyncssh',
            'libnacl',
            'plyer'
        ],
        ext_modules=cythonize([
            Extension('libangelos', ['libangelos.c'])
        ]),
        cmdclass={'build_ext': build_ext}
    )


COMPILE_MAP = {
    'libar7': build_libar7,
    'libeidon': build_libeidon,
    'libangelos': build_libangelos
}


if __name__ == '__main__':
    build = set(COMPILE_MAP.keys()).intersection(set(sys.argv))
    print(build)
    for b in build:
        COMPILE_MAP[b]()
