default:
	cython angelos.py --embed
	python setup.py build

clean:
	rm -fr *.c *.o *.so *.app *.spec MANIFEST
	rm -fr build
	rm -fr dist
