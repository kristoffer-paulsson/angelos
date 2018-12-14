# The path to the static libraries directory
LIBRARY_DIRS = -L.
# The path to the headers to be included directory
INCLUDE_DIRS = -I../venv/include/python3.7m
# A list of the static libraries to statically link
STATIC_LIBS = libpython3.7m.a
# A list of the dynamic libreries to dynamically link
DYNANIC_LIBS = -lpthread -lm -lutil -ldl
# The name of the executable binary
MODULE = test

# How to compile an executable binary
default:
	# Soft link all static libraries to a certain library folder
	ln -sf ../venv/lib/python3.7/config-3.7m-darwin/libpython3.7m.a
	# Cythonize the entrypoint python script
	cython --embed -o $(MODULE).c $(MODULE).py
	# Compile and link executable binary
	gcc -Os $(LIBRARY_DIRS) $(INCLUDE_DIRS) $(DYNAMIC_LIBS) -o $(MODULE) $(STATIC_LIBS) $(MODULE).c
