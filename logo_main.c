#include <Python.h>
#include "logo_entrypoint.h"

int main(int argc, char *argv[]) {
    PyImport_AppendInittab("logo", PyInit_angelos);
    Py_Initialize();
    start() // Imported from logo_entrypoint
    Py_Finalize();
}
