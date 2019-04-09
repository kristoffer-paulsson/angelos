import sys
sys.path.append('../angelos')  # noqa

import argparse
import logging
import asyncio

import asyncssh

from lipsum import LIPSUM_RSA_PRIVATE, LIPSUM_RSA_PUBLIC


def handle_client(process):
    print(process.env, process.command, process.subsystem)
    process.stdout.write(
        'Welcome to my SSH server, %s!\n' %
        process.get_extra_info('username'))
    process.exit(0)


class SSHServer(asyncssh.SSHServer):
    def connection_made(self, conn):
        print(
            'SSH connection received from %s.' %
            conn.get_extra_info('peername')[0])

    def connection_lost(self, exc):
        if exc:
            print('SSH connection error: ' + str(exc), file=sys.stderr)
        else:
            print('SSH connection closed.')

    def begin_auth(self, username):
        return False

    def password_auth_supported(self):
        return True

    def validate_password(self, username, password):
        return password == 'qwerty'


async def start_server():
    await asyncssh.create_server(
        SSHServer, '', 22, server_host_keys=[
            asyncssh.import_private_key(LIPSUM_RSA_PRIVATE)],
        authorized_client_keys=asyncssh.import_authorized_keys(
            LIPSUM_RSA_PUBLIC), process_factory=handle_client)


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
