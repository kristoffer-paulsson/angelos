### cython-stuff

How to find libraries in UNIX
find /Library -name "*python*.a" 2>&1 | grep -v "find:"
Extensions to look for *.a, *.dylib, *.o, *.so

pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install -U

http://hplgit.github.io/primer.html/doc/pub/cython/cython-readable.html
https://cython.readthedocs.io/en/latest/src/tutorial/clibraries.html
