
from setuptools import setup
# from setuptools.extension import Extension
from Cython.Build import cythonize

# import numpy
from os import path

here = path.abspath(path.dirname(__file__))
with open(path.join(here, 'README.md'), encoding='utf-8') as f:
    long_description = f.read()

# gcc angelos.c -I .env/include/python3.7m/


setup(
    name='angelos',  # Required
    version='0.1a1',  # Required
    description='A safe messaging system',  # Required
    long_description=long_description,  # Optional
    long_description_content_type='text/markdown',  # Optional (see note above)
    url='https://github.com/kristoffer-paulsson/angelos',  # Optional
    author='Kristoffer Paulsson',  # Optional
    author_email='kristoffer.paulsson@talenten.se',  # Optional
    classifiers=[  # Optional
        'Development Status :: 3 - Alpha',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3.7',
    ],
    # packages=find_packages(exclude=['contrib', 'docs', 'tests']),  # Required
    install_requires=[''],
    extras_require={  # Optional
        'dev': ['cython', 'asyncssh', 'libnacl'],
        'test': [''],
    },
    package_data={  # Optional
        # 'sample': ['package_data.dat'],
    },
    # data_files=[('my_data', ['data/data_file'])],  # Optional
    entry_points={  # Optional
        'console_scripts': [
            'angelos=angelos:main',
        ],
    },
    # setup_requires=['pbr'],
    # pbr=True,
    ext_modules=cythonize('angelos.py', include_path=[
        'angelos/*.py', 'angelos/server/*.py']),
)
