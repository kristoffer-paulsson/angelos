"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import sys
sys.path.append('../angelos')  # noqa

import argparse
import logging
import asyncio
import base64
import json

import asyncssh

from angelos.ssh.nacl import NaClKey, NaClPrivateKey, NaClPublicKey


C_ENTITY = json.loads("""
{
    "signature":"cfh7LYyRPe5sYAMjd3gww+Gr8fV04Kn9oQK/VaG/6WDbrbxXmMK83fLH/R5vLgwLMdDL5gmqO00s8DsMDdtpDQ==",
    "issuer":"689115f1-c7d9-4a99-8c88-f24e98b12198",
    "id":"689115f1-c7d9-4a99-8c88-f24e98b12198",
    "created":"2019-04-10",
    "expires":"2020-05-09",
    "type":"Type.ENTITY_PERSON",
    "updated":"",
    "gender":"man",
    "born":"1944-06-19",
    "names":[
        "Moshe",
        "Jerald",
        "Tommy"
    ],
    "family_name":"Simmons",
    "given_name":"Moshe"
}
""")

C_PRIVKEYS = json.loads("""
{
    "signature":"myrmtqlvH1zMjYlQveJSsrBks8gwiGZspl0NS8DzPtCAYdHgJt/SIUxWGsLR5b4Gthb8T54KWiqTDzvH7vrTBQ==",
    "issuer":"689115f1-c7d9-4a99-8c88-f24e98b12198",
    "id":"ad14b831-58b7-484f-b893-a8ec0a150738",
    "created":"2019-04-10",
    "expires":"2020-05-09",
    "type":"Type.KEYS_PRIVATE",
    "secret":"85CLYXEud5kkBDzlyQCIqg8rP9qzqStls2DtklMxlXI=",
    "seed":"mCAJLjA5+GYy/PqOtLBenMXuvBdoO3oq5iCfmPpbXyU="
}
""")

C_KEYS = json.loads("""
{
    "signature":[
        "s3uHdmJMr7XP/LsymSdZgud/Xs6ae+jeMtqj8wnNUGdHqL+GK91uXKzX2iXYr2a0qk83kc5T9x4SYUYb9RgLCg=="
    ],
    "issuer":"689115f1-c7d9-4a99-8c88-f24e98b12198",
    "id":"4775c8f4-7836-4a07-a955-a0715812d1a9",
    "created":"2019-04-10",
    "expires":"2020-05-09",
    "type":"Type.KEYS",
    "verify":"c9ktYXZw90WAmYOEkVSJs4/A6EyDAgRgS7RkjyddNaM=",
    "public":"oLgE2RquIEaDdvEqCNnJLd8WUJTu+HQ1fLd6NGNhwD4="
}
""")

S_ENTITY = json.loads("""
{
    "signature":"tzmqjUfDzwF+d1eWlKs1xTCDDMaJVMzr+B8VQt55pS1qu63Z0bnWboNVn4BhkXwtCAU0Lk2DzjqcQgpMKD5DDQ==",
    "issuer":"0ba92425-2115-417f-82d9-275fdbc9f371",
    "id":"0ba92425-2115-417f-82d9-275fdbc9f371",
    "created":"2019-04-11",
    "expires":"2020-05-10",
    "type":"Type.ENTITY_CHURCH",
    "updated":"",
    "founded":"2011-02-03",
    "city":"Reno",
    "state":"Nevada",
    "nation":"USA"
}
""")  # noqa E501

S_KEYS = json.loads("""
{
    "signature":[
        "132+PY4RVSK8GbZ+JKEbpAmMhLoQcX6xFRJF3/fe8rKjhQo3Ipvl3Rv9y4ohBj6w4eqU6kMxoBGFnz7d5OANDw=="
    ],
    "issuer":"0ba92425-2115-417f-82d9-275fdbc9f371",
    "id":"a2753511-babf-43d7-a7e2-5179df511704",
    "created":"2019-04-11",
    "expires":"2020-05-10",
    "type":"Type.KEYS",
    "verify":"zjU+rdsJFpvjiPbimApq+6cGxZ6CebTYLH4Xzbj3y8o=",
    "public":"JqSTQijOBVJON+0tuojowqgy1aEokAy6/ppm5OIMEC4="
}
""")  # noqa E501


class MySSHClientSession(asyncssh.SSHClientSession):
    def data_received(self, data, datatype):
        print(data, datatype, end='')

    def connection_lost(self, exc):
        if exc:
            print('SSH session error: ' + str(exc), file=sys.stderr)


class SSHClient(asyncssh.SSHClient):
    def __init__(self, keylist=(), delay=0):
        # self._keylist = keylist
        self._keylist = import_client_keys()
        self._delay = delay

    def connection_made(self, conn):
        print('connection_made')
        print(type(conn), conn)
        pass  # pragma: no cover

    def connection_lost(self, exc):
        print('connection_lost')
        if isinstance(exc, type(None)):
            print('Connection closed')
        else:
            print('Connection unexpectedly closed')
            print(type(exc), exc)
        pass  # pragma: no cover

    def debug_msg_received(self, msg, lang, always_display):
        print('debug_msg_received')
        print(msg, lang, always_display)
        pass  # pragma: no cover

    def auth_banner_received(self, msg, lang):
        print('auth_banner_received')
        print(msg, lang)
        pass  # pragma: no cover

    def auth_completed(self):
        print('auth_completed')
        pass  # pragma: no cover

    @asyncio.coroutine
    def public_key_auth_requested(self):
        """Return a public key to authenticate with"""
        print('public_key_auth_requested')
        if self._delay:
            yield from asyncio.sleep(self._delay)
        return self._keylist.pop(0) if self._keylist else None


async def run_client():
    conn, client = await asyncssh.create_connection(
        SSHClient, 'localhost',
        known_hosts=known_hosts,
        username=C_ENTITY['issuer'],
        kex_algs=('diffie-hellman-group18-sha512', ),
        encryption_algs=('chacha20-poly1305@openssh.com', ),
        mac_algs=('hmac-sha2-512-etm@openssh.com', ),
        compression_algs=('zlib', ),
        signature_algs=('angelos-tongues', )
    )
    print(type(client), client)
    conn.close()
    # async with conn:
    #    chan, session = await conn.create_session(MySSHClientSession)
    #    await chan.wait_closed()


def import_client_keys():
    return [
        NaClKey(key=NaClPrivateKey.construct(
            base64.b64decode(C_PRIVKEYS['seed'])))]


def known_hosts(h, a, p):
    return (
        [NaClKey(key=NaClPublicKey.construct(
            base64.b64decode(S_KEYS['verify'])))], [], [])


def main():
    try:
        asyncio.get_event_loop().run_until_complete(run_client())
    except (OSError, asyncssh.Error) as exc:
        sys.exit('SSH connection failed: ' + str(exc))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Unittesting')
    parser.add_argument(
        '--debug', help='Debugging', action='store_true', default=False)

    args = parser.parse_args()
    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    asyncssh.logging.set_debug_level(3)
    # unittest.main(argv=['first-arg-is-ignored'])
    main()
