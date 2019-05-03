VERSION = 3.7
PYTHON = python$(VERSION)

INC = /Library/Frameworks/Python.framework/Versions/$(VERSION)/include/$(PYTHON)m
LIB = /Library/Frameworks/Python.framework/Versions/$(VERSION)/lib
BUILD = build/

INC_PATH = $(realpath ./include)
ENV_DIR = $(realpath ./venv)
ROOT_DIR = $(realpath ./)
INST_PATH = $(ENV_DIR)


export INC_PATH
export INST_PATH

pysetup:
	python setup.py build_ext --inplace

libangelos:
	cython -o libangelos.c -3 $(shell python setup/modules.py -m angelos)

libeidon:
	cython -o eidon.c -3 $(shell python setup/modules.py -m eidon)

libar7:
	cython -o libar7.c -3 angelos/error.py angelos/utils.py angelos/ioc.py angelos/archive/conceal.py angelos/archive/archive7.py

default:





ar7: libar7
	cython -o ar7.c ar7.py -3 --embed
	gcc -v -Os -I $(INC) -L $(LIB) -o ar7 libar7.c ar7.c -l$(PYTHON)  -lpthread -lm -lutil -ldl



test:
	$(MAKE) -C $(INC_PATH) -f $@.mk -e
	@echo ========================= test SUCCESS =========================

clean:
	rm -Rf ./**/*.c
	rm -Rf ./**/*.o
	rm -Rf ./**/*.pyc
	rm -Rf ./**/__pycache__
	rm -fr *.c *.o *.so *.app *.spec MANIFEST *.build /build/ build *.dist /dist/ .DS_Store *.log
	rm ar7

env:
	# --relocatable --python=$(PYV)
	virtualenv --download --always-copy $(ENV_DIR)
	virtualenv --relocatable $(ENV_DIR)

setup:
	pip install -U 'http://nuitka.net/gitweb/?p=Nuitka.git;a=snapshot;h=refs/heads/develop;sf=tgz'
	pip install asyncssh # dependencies
	pip install kivy
	pip install -U 'https://gitlab.com/kivymd/KivyMD/-/archive/master/KivyMD-master.tar.bz2'
	pip install -U 'https://codeload.github.com/kivy/plyer/zip/1.3.0'

doc:
	pydoc -w angelos
	pydoc -w $(find angelos -name '*.py' | tr '/' '.' | sed 's/.\{3\}$//')
	mv *.html docs
