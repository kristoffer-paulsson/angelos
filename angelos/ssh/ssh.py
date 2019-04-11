import asyncssh


class SSHServer(asyncssh.SSHServer):
    def connection_made(self, conn):
        pass  # pragma: no cover

    def connection_lost(self, exc):
        pass  # pragma: no cover

    def debug_msg_received(self, msg, lang, always_display):
        pass  # pragma: no cover

    def begin_auth(self, username):
        return True  # pragma: no cover

    def auth_completed(self):
        pass  # pragma: no cover

    def public_key_auth_supported(self):
        return True  # pragma: no cover

    def validate_public_key(self, username, key):
        return False  # pragma: no cover

    def session_requested(self):
        return False  # pragma: no cover

    def connection_requested(self, dest_host, dest_port, orig_host, orig_port):
        return False  # pragma: no cover

    def server_requested(self, listen_host, listen_port):
        return False  # pragma: no cover


class SSHClient(asyncssh.SSHClient):
    def connection_made(self, conn):
        pass  # pragma: no cover

    def connection_lost(self, exc):
        pass  # pragma: no cover

    def debug_msg_received(self, msg, lang, always_display):
        pass  # pragma: no cover

    def auth_banner_received(self, msg, lang):
        pass  # pragma: no cover

    def auth_completed(self):
        pass  # pragma: no cover

    def public_key_auth_requested(self):
        return None  # pragma: no cover
