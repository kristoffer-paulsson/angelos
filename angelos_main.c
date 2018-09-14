#include <Python.h>
#include "angelos_entrypoint.h"

int main(int argc, char *argv[]) {
    PyImport_AppendInittab("angelos", PyInit_angelos);
	Py_Initialize();
    start() // Imported from angelos_entrypoint
	Py_Finalize();
}
