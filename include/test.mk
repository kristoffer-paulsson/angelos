LIBRARY_DIRS = -L.
INCLUDE_DIRS = -I../venv/include/python3.7m
STATIC_LIBS = libpython3.7m.a
DYNANIC_LIBS = -lpthread -lm -lutil -ldl
MODULE = test

default:
	ln -sf ../venv/lib/python3.7/config-3.7m-darwin/libpython3.7m.a
	cython --embed -o $(MODULE).c $(MODULE).py
	gcc -Os $(LIBRARY_DIRS) $(INCLUDE_DIRS) $(DYNAMIC_LIBS) -o $(MODULE) $(STATIC_LIBS) $(MODULE).c
