# To do

## Angelos server integration
* Develop/build system service configuration.
  * Dbus: 
    * https://www.freedesktop.org/software/systemd/man/systemd.service.html
    * https://www.freedesktop.org/software/systemd/man/systemd.exec.html
    * https://www.freedesktop.org/software/systemd/man/systemd.kill.html
  * SysV: ...
  * Windows services: ...
* Develop/build start and stop scripts for the server.

## Design goals

The server should support the following directories

* WORKING_DIRECTORY, --work-dir=,
* ROOT_DIRECTORY, --root-dir=, root directory is the chrooted environment
* RUNTIME_DIRECTORY, --run-dir=
* STATE_DIRECTORY, --state-dir=, directory where the archives are saved.
* LOGS_DIRECTORY, --logs-dir=, directory for the log files.
* CONFIGURATION_DIRECTORY, --conf-dir=, directory of the configuration files.