#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#

PYI = --log=DEBUG --onefile
AR7_IMPORT = uuid pathlib

.PHONY: docs
default:

init:
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
	rm -fr ./angelos-*/dist/
	rm -fr ./angelos-*/build/
	find ./angelos-*/src -name \*.egg-info -type f -delete
	find ./angelos-*/src -name \*.so -type f -delete
	find ./angelos-*/src -name \*.dylib -type f -delete
	find ./angelos-*/src -name \*.dll -type f -delete
	rm -fr ./docs/html/
	rm -fr ./docs/doctrees/

docs: basic
	sphinx-apidoc -o docs lib/angelos
	sphinx-build -M html docs docs

test:
	python ./tests/test_certified.py

run:
    python ./bin/angelos config --run-dir=$(pwd) --state-dir=$(pwd) --logs-dir=$(pwd) --conf-dir=$(pwd)