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
