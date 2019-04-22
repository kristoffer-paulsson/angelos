INC_PATH = $(realpath ./include)
ENV_DIR = $(realpath ./venv)
ROOT_DIR = $(realpath ./)
INST_PATH = $(ENV_DIR)
PY_VER = python3.7

export INC_PATH
export INST_PATH

default:
	cython -o libangelos.c -3 $(shell python setup/modules.py -m angelos)
	cython -o eidon.c -3 $(shell python setup/modules.py -m eidon)
	python setup.py build_ext

# @echo ========================= make SUCCESS =========================

test:
	$(MAKE) -C $(INC_PATH) -f $@.mk -e
	@echo ========================= test SUCCESS =========================

clean:
	rm -Rf angelos/**/*.c
	rm -Rf angelos/**/*.o
	rm -Rf angelos/**/*.pyc
	rm -Rf ./**/__pycache__
	rm -fr *.o *.so *.app *.spec MANIFEST *.build /build/ build *.dist /dist/ .DS_Store *.log

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
