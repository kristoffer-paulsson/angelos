from setuptools import setup
from distutils.extension import Extension
from Cython.Build import cythonize
from Cython.Distutils import build_ext


extensions = [
    Extension('libangelos', ['libangelos.c']),
    Extension('eidon', ['eidon.c']),
]


setup(
    name='angelos',
    version='0.1a1',
    description='A safe messaging system',
    author='Kristoffer Paulsson',
    author_email='kristoffer.paulsson@talenten.se',
    url='https://github.com/kristoffer-paulsson/angelos',
    license='MIT',
    packages=['angelos'],
    install_requires=[
        'asyncssh',  # six, asn1crypto, idna, pycparser, cffi, cryptography
        'libnacl',
    ],
    ext_modules=cythonize(extensions),
    cmdclass={'build_ext': build_ext}
)
