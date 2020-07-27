from pathlib import Path

from setuptools import setup, Extension, Command as _Command
from setuptools.command.install import install as setup_install
from Cython.Build import cythonize
from Cython.Compiler import Options

"""
cython --embed -3 -o ./bin/test.c ./bin/test.pyx
gcc -o ./bin/test.o -c ./bin/test.c `./usr/local/bin/python3.7-config --cflags`
gcc -o ./bin/test ./bin/test.o `./usr/local/bin/python3.7-config --ldflags`
"""

Options.embed = "main"
Options.docstrings = False

setup(
    name="test",
    ext_modules=cythonize(
        [
            Extension(
                name="test",
                sources=["bin/test.pyx"],
                include_dirs=[str(Path("./usr/local/include/python3.7m").absolute())],
                libraries=[],
                library_dirs=[],
                extra_objects=[
                    "usr/local/lib/libpython3.7m.a"
                ],
            )
        ],
        build_dir="build",
        compiler_directives={
            "language_level": "3",
        }
    )
)