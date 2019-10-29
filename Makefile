PYI = --log=DEBUG --onefile
AR7_IMPORT = uuid pathlib

.PHONY: docs
default:


basic:
	mkdir -p angelos
	mkdir -p angelos/archive
	mkdir -p angelos/client
	mkdir -p angelos/client/ui
	mkdir -p angelos/data
	mkdir -p angelos/document
	mkdir -p angelos/dummy
	mkdir -p angelos/facade
	mkdir -p angelos/operation
	mkdir -p angelos/policy
	mkdir -p angelos/replication
	mkdir -p angelos/server
	mkdir -p angelos/ssh
	pip install -r requirements.txt
	python setup.py develop

logo: basic
	python ./setup/logo_spec.py
	pyinstaller logo.spec ./bin/logo $(PYI) --windowed

angelos: basic
	pyinstaller ./bin/angelos $(PYI)

ar7: basic
	python ./setup/ar7_spec.py
	pyinstaller ./ar7.spec  $(PYI)

clean:
	rm -fr ./dist/
	rm -fr ./build/
	rm -fr ./angelos/**/*.so
	rm -fr ./docs/html/
	rm -fr ./docs/doctrees/

docs: angelos
	sphinx-apidoc -o docs lib/angelos
	sphinx-build -M html docs docs
