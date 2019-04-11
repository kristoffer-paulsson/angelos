import sys
sys.path.append('../angelos')  # noqa

import argparse
import logging
import asyncio
import base64
import json

import asyncssh

from angelos.ssh.nacl import NaClKey, NaClPublicKey, NaClPrivateKey


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

S_PRIVKEYS = json.loads("""
{
    "signature":"5BDEdwgOLpZ0RgENEk8hL+swQmGcFV0ths/lIbBVFs+yZgU1QDCUR4bsO86F05wKU72Sz4XzEb/Pu//S3lLPBw==",
    "issuer":"0ba92425-2115-417f-82d9-275fdbc9f371",
    "id":"bd535f26-72f1-45d0-8292-1fe370bc0fad",
    "created":"2019-04-11",
    "expires":"2020-05-10",
    "type":"Type.KEYS_PRIVATE",
    "secret":"iQCUZ3yT/7DPS3zK+Aff4AN+YDbPeqkgBnKQmU70RAs=",
    "seed":"gl/TQGdPKhIW/l1sjQpS9Mbh99iL1xfhZMY5SzZLcY4="
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
""")  # noqa E501

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
""")  # noqa E501


def handle_client(process):
    print(process.env, process.command, process.subsystem)
    process.stdout.write(
        'Welcome to my SSH server, %s!\n' %
        process.get_extra_info('username'))
    process.exit(0)


class SSHServer(asyncssh.SSHServer):
    def __init__(self, client_keys=()):
        self._conn = None
        # self._client_keys = client_keys
        self._client_keys = import_client_keys()

    def connection_made(self, conn):
        print('connection_made')
        self._conn = conn
        conn.send_auth_banner('auth banner')

    def connection_lost(self, exc):
        print('connection_lost')
        print(type(exc), exc)
        pass  # pragma: no cover

    def debug_msg_received(self, msg, lang, always_display):
        print('debug_msg_received')
        print(msg, lang)
        pass  # pragma: no cover

    def begin_auth(self, username):
        print('begin_auth')
        # self._client_keys = asyncssh.load_public_keys(self._client_keys)
        return True

    def auth_completed(self):
        print('auth_completed')
        pass  # pragma: no cover

    def public_key_auth_supported(self):
        print('public_key_auth_supported')
        return True  # pragma: no cover

    def validate_public_key(self, username, key):
        print('validate_public_key')
        print(username, type(key))
        # return key.key == self._client_keys._key.key
        return key in self._client_keys

    def session_requested(self):
        print('session_requested')
        return False  # pragma: no cover

    def connection_requested(self, dest_host, dest_port, orig_host, orig_port):
        print('connection_requested')
        return False  # pragma: no cover

    def server_requested(self, listen_host, listen_port):
        print('server_requested')
        return False  # pragma: no cover


async def start_server():
    await asyncssh.create_server(
        SSHServer, 'localhost', 22,
        server_host_keys=[import_private_key()],
        process_factory=handle_client,
        # kex_algs=('diffie-hellman-group18-sha512', ),
        # encryption_algs=('chacha20-poly1305@openssh.com', ),
        # mac_algs=('hmac-sha2-512-etm@openssh.com', ),
        # compression_algs=('zlib', ),
        # signature_algs=('angelos-tongues', )
    )


def import_client_keys():
    return [NaClKey(
        key=NaClPublicKey.construct(base64.b64decode(C_KEYS['verify'])))]


def import_private_key():
    return NaClKey(
        key=NaClPrivateKey.construct(base64.b64decode(S_PRIVKEYS['seed'])))


def main():
    loop = asyncio.get_event_loop()
    try:
        loop.run_until_complete(start_server())
    except (OSError, asyncssh.Error) as exc:
        sys.exit('Error starting server: ' + str(exc))
    loop.run_forever()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Unittesting')
    parser.add_argument(
        '--debug', help='Debugging', action='store_true', default=False)

    args = parser.parse_args()
    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    # unittest.main(argv=['first-arg-is-ignored'])
    main()
