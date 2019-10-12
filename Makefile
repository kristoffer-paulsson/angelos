PYI = --log=DEBUG --onefile
AR7_IMPORT = uuid pathlib

.PHONY: docs
default:


basic:
	# pip install -U -r requirements.txt
	python setup.py develop

logo: basic
	pyinstaller ./bin/logo $(PYI)

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

docs:
	sphinx-apidoc -o docs lib/angelos
	sphinx-build -M html docs docs
