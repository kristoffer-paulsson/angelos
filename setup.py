from distutils.core import setup, Extension
from Cython.Build import cythonize
# from Cython.Compiler import Options
# import numpy

# Options.embed = 'main'

extensions = [
    Extension(
        'angelos_lib',
        sources=['angelos/server/main.pyx'],
    )
]

setup(
    name='angelos',
    version='0.1a1',
    description='A safe messaging system',
    author='Kristoffer Paulsson',
    author_email='kristoffer.paulsson@talenten.se',
    url='https://github.com/kristoffer-paulsson/angelos',
    license='MIT',
    ext_modules=cythonize(extensions)
)
