#!/usr/bin/env python

from distutils.core import setup, Extension
from Cython.Build import cythonize
from Cython.Compiler import Options
# import numpy

Options.embed = 'main'

extensions = [
    Extension(
        'angelos', [
            'angelos.py',
        ],
        include_dirs=[],
        compiler_directives={
            'embedsignature': True,
            'language_level': 3,
            'cdivision': True,  # speed improvements if True
            'overflowcheck': True,  # speed improvements
            'nonecheck': False,  # speed improvements
        },
        build_dir='build/server',
        extra_compile_args=[],
        extra_link_args=[]
    )
]

setup(
    name='Distutils',
    version='0.1a1',
    description='Python Distribution Utilities',
    author='Kristoffer Paulsson',
    author_email='kristoffer.paulsson@talenten.se',
    url='https://github.com/kristoffer-paulsson/angelos',
    license='MIT',
    ext_modules=cythonize(extensions)
)
