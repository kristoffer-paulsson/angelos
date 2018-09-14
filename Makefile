INC_PATH = $(realpath ./include)
ENV_DIR = $(realpath ./venv)
ROOT_DIR = $(realpath ./)
INST_PATH = $(ENV_DIR)
PY_VER = python3.7

export INC_PATH
export INST_PATH

default: sqlcipher
	@echo ========================= make SUCCESS =========================

sqlcipher: openssl
	$(MAKE) -C $(INC_PATH) -f $@.mk -e
	@echo ========================= sqlcipher SUCCESS =========================

openssl:
	$(MAKE) -C $(INC_PATH) -f $@.mk -e
	@echo ========================= openssl SUCCESS =========================

# --recurse-not-to
# python -m nuitka --recurse-all --standalone --show-progress --verbose angelos.py
# python -m nuitka --recurse-all --standalone logo.py

clean:
	rm -fr *.c *.o *.so *.app *.spec MANIFEST *.build /build/ *.dist /dist/

env:
	# --relocatable --python=$(PYV)
	virtualenv --download --always-copy $(ENV_DIR)
	virtualenv --relocatable $(ENV_DIR)

setup:
	pip install -U 'http://nuitka.net/gitweb/?p=Nuitka.git;a=snapshot;h=refs/heads/develop;sf=tgz'
	pip install asyncssh # dependencies
	pip install kivy
	pip install -U 'https://gitlab.com/kivymd/KivyMD/-/archive/master/KivyMD-master.tar.bz2'
