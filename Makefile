ENV ="venv"				# Virtual environment folder name
PYV ="python3.7"			# Python version

# --recurse-not-to
default:
	python -m nuitka --recurse-all --recurse-to=types --standalone angelos.py
	python -m nuitka --recurse-all --recurse-to=types --standalone logo.py

clean:
	rm -fr *.c *.o *.so *.app *.spec MANIFEST
	rm -fr *.build
	rm -fr *.dist

env:
	# --relocatable --python=$(PYV)
	virtualenv --download --always-copy $(ENV)
	virtualenv --relocatable $(ENV)

setup:
	pip install -U 'http://nuitka.net/gitweb/?p=Nuitka.git;a=snapshot;h=refs/heads/develop;sf=tgz'
	pip install nuitka-setuptools # tools
	pip install asyncssh # dependencies

#env_in:
#	deactivate
