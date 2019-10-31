PYI = --log=DEBUG --onefile
AR7_IMPORT = uuid pathlib

.PHONY: docs
default:

init:
	mkdir -p libangelos
	mkdir -p libangelos/archive
	mkdir -p libangelos/client
	mkdir -p libangelos/client/ui
	mkdir -p libangelos/data
	mkdir -p libangelos/document
	mkdir -p libangelos/dummy
	mkdir -p libangelos/facade
	mkdir -p libangelos/operation
	mkdir -p libangelos/policy
	mkdir -p libangelos/replication
	mkdir -p libangelos/server
	mkdir -p libangelos/ssh
	mkdir -p angelos
	pip install -r requirements.txt
	python setup.py develop

basic:
	python setup.py develop

angelos: basic
	python ./setup/angelos_spec.py
	pyinstaller angelos.spec ./bin/angelos $(PYI)

ar7: basic
	python ./setup/ar7_spec.py
	pyinstaller ./ar7.spec  $(PYI)

clean:
	rm -fr ./dist/
	rm -fr ./build/
	rm -fr ./angelos/**/*.so
	rm -fr ./docs/html/
	rm -fr ./docs/doctrees/

docs: basic
	sphinx-apidoc -o docs lib/angelos
	sphinx-build -M html docs docs
