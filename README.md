README is a matter of @todo

# angelos

Ἄγγελος is a safe messenger system. Angelos means "Carrier of a divine message."

* SSH / Terminal
    - Client 2 Node, for administering the server
* SSH / Replication
    - Node 2 Node, replication messages and documents
    - Client 2 Node, syncronizing specific messages and documents
* SSH / Instant service broker / session
    - Node 2 Client, for online availability
    - Client 2 Client, for chat/calling/sharing
* SSH / FTP
    - Client 2 Node, only administrator can upload
    - Node 2 Client, for downloading common files
* SSH / Passthru
    - Client 2 Node 2 Node 2 Client, reserved for future use
* TLS / HTTP / REST
    - Node 2 Client, socialmedia portal platform

Λόγῳ is a safe messenger client. Logo means "Word, saying, matter, statement, remark, reason"

## Basic setup

Install the requirements:
```
$ pip install -r requirements.txt
```

Run the application:
```
$ python -m angelos --help
```

To run the tests:
```
    $ pytest
```


## Links'n'stuff
https://git-scm.com/docs/gitmodules

https://wiki.python.org/moin/BuildStatically
http://mdqinc.com/blog/2011/08/statically-linking-python-with-cython-generated-modules-and-packages/
https://stackoverflow.com/questions/1150373/compile-the-python-interpreter-statically
https://groups.google.com/forum/?hl=en#!topic/comp.lang.python/66fDI6AiG5c

https://github.com/sqlcipher/sqlcipher
https://github.com/rigglemania/pysqlcipher3
http://charlesleifer.com/blog/encrypted-sqlite-databases-with-python-and-sqlcipher/

### Python
git clone -b 3.7 https://github.com/python/cpython.git
./configure --disable-shared && make

### cython-stuff
https://cython.readthedocs.io/en/latest/src/tutorial/clibraries.html

### kivy / garden / KivyMD

pip install kivy
pip install kivy-garden
pip install -U 'https://gitlab.com/kivymd/KivyMD/-/archive/master/KivyMD-master.tar.bz2'
