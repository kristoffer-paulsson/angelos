PYI = --log=DEBUG --onefile
AR7_IMPORT = uuid pathlib

default:


basic:
	# pip install -U -r requirements.txt
	python setup.py develop

angelos: basic
	pyinstaller ./bin/angelos --onefile

ar7: basic
	python ./setup/ar7_spec.py
	pyinstaller ./ar7.spec  $(PYI)

clean:
	rm -fr ./dist/
	rm -fr ./build/
	rm -fr ./angelos/**/*.so
	# find ./lib/ -name '*.c' -delete
