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

.PHONY: install check clean
default:
	echo ""

install:
	python setup.py venv --prefix=$(DESTDIR)

check:
	echo ""

clean:
	rm -fr ./dist/
	rm -fr ./build/
	rm -fr ./angelos-*/dist/
	rm -fr ./angelos-*/build/
	find ./angelos-*/src -name \*.egg-info -type f -delete
	find ./angelos-*/src -name \*.so -type f -delete
	find ./angelos-*/src -name \*.dylib -type f -delete
	find ./angelos-*/src -name \*.pyd -type f -delete
	rm -fr ./docs/html/
	rm -fr ./docs/doctrees/

