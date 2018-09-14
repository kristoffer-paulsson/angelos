from distutils.core import setup
from Cython.Build import cythonize
from distutils.extension import Extension


sourcefiles = ['logo.py']
extensions = [Extension("logo", sourcefiles)]

setup(
    name='angelos',
    version='0.1a1',
    description='A safe messaging system',
    author='Kristoffer Paulsson',
    author_email='kristoffer.paulsson@talenten.se',
    url='https://github.com/kristoffer-paulsson/angelos',
    license='MIT',
    packages=['angelos', 'angelos.server', 'angelos.client'],
    install_requires=[
        'asyncssh',  # six, asn1crypto, idna, pycparser, cffi, cryptography
        'libnacl',
        'pyyaml',
        'peewee',
        'pysqlcipher3'
    ],
    ext_modules=cythonize(extensions)
)
