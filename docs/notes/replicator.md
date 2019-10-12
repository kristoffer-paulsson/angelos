# Replicator protocol

Protocol for the Angelos project replication SSH subsystem. The replicator is the most essential part in an Angelos network for synchronizing Archive7 archives, according to certain rules depending on purpose.

### Initialization

The client will send an initialization package to the server with client version:

> client ----> server
> type: RPL_INIT

The server responds the currently supported protocol versions.

> client <---- server
> type: RPL_VERSION

The client responds with a valid version and a preset or parameters for which operation to carry out.

> client ----> server
> type: RPL_OPERATION

> parameters:
>> version: int
>> last-modified: datetime/null
>> preset: str/custom

>> archive: str
>> path: str
>> owner: uuid/null

Then the server will reply whether it accepts or denies the proposed operation.

> client <---- server
> type: RPL_CONFIRM

After this initialization and negotiation the session either closes or the synchronization operation begins.

### Replication

The client will run a replication cycle of packets for each file. There are two types synchronization requests: PUSH and PULL. A PUSH request is when the client sends a PULL regarding a file, the server will respond with its...

#### Pull/push from server

The first step in the replication is to pull all pullable files from the server.

The client queries for a file to synchronize

> client ----> server
> type: RPL_REQUEST

> parameters:
>> action: PULL / PUSH
>> id: uuid / null
>> path: str / null
>> modified: datetime / null
>> deleted: bool

The server responds with a file, its path, uuid, last-modified. If not files to pull the server responds it is done.

> client <---- server
> type: RPL_RESPONSE / RPL_DONE

> parameters:
>> id: uuid / null
>> path: str / null
>> modified: datetime / null
>> deleted: bool

The client responds with its copys path, uuid, last-modified and suggests how to synchronize.

> client ----> server
> type: RPL_SYNC

> parameters:
>> action: (sync-type)
>> id: uuid / null
>> path: str / null
>> modified: datetime / null
>> deleted: bool

> Sync types
>> client-create
>> client-update
>> client-delete
>> server-create
>> server-update
>> server-delete

Server responds whether it accepts synchronization suggestion or not.

> client <---- server
> type: RPL_CONFIRM

> parameters:
>> answer: bool


If the sync suggestion is client-create/update, the client will download the file.
If the sync suggestion is server-create/update, the client will upload the file.
If the sync suggestion is client-delete. The client will delete the file at sending RPL_SYNC.
If the sync suggestion is server-delete. The server will delete the file before sending RPL_CONFIRM.

#### Download from server

The client requests to download a file.

> client ----> server
> type: RPL_DOWNLOAD

> parameters:
>> id: uuid
>> path: str

The server responds with a confirmation.

> client <---- server
> type: RPL_CONFIRM

> parameters:
>> pieces: int
>> size: int

The client will start asking for chunks. Chunk null is always the metadata of the file.

> client ----> server
> type: RPL_GET

> parameters:
>> type: str (meta/data)
>> piece: int

The server will serve a chunk.

> client <---- server
> type: RPL_CHUNK

> parameters:
>> type: str (meta/data)
>> piece: int
>> data: bytes

When all chunks are requested and served the client will inform the server.

> client ----> server
> type: RPL_DONE

#### Upload to server

The client requests to upload a file.

> client ----> server
> type: RPL_UPLOAD

> parameters:
>> id: uuid
>> path: str
>> size: int

The server responds with a confirmation.

> client <---- server
> type: RPL_CONFIRM

The client will start sending chunks to the server.

> client ----> server
> type: RPL_PUT

> parameters:
>> type: str (meta/data)
>> piece: int
>> data: bytes

The server will confurm a received chunk.

> client <---- server
> type: RPL_RECEIVED

> parameters:
>> type: str (meta/data)
>> piece: int

When all chunks are uploaded and served the client will inform the server.

> client ----> server
> type: RPL_DONE

When all synchronization is done the client closes the session.

> client ----> server
> type: RPL_CLOSE

At any time if something doesn't work the server can abort an sync or the session.

> client <---- server
> type: RPL_ABORT
