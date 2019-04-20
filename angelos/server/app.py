"""Module docstring."""
import os
import asyncio

from ..utils import Util
from ..const import Const
from ..ioc import ContainerAware
from ..starter import Starter


class Application(ContainerAware):
    """Main server application class."""

    def __init__(self, ioc):
        """Initialize app logger."""
        ContainerAware.__init__(self, ioc)
        self._applog = self.ioc.log.app

    def _initialize(self):
        vault_file = Util.path(self.ioc.runtime.home, Const.CNL_VAULT)
        if os.path.isfile(vault_file):
            self._applog.info(
                'Vault archive found. Initialize startup mode.')
        else:
            self._applog.info(
                'Vault archive NOT found. Initialize setup mode.')
            # socket.getfqdn()  # Fully qualified domain name
            # socket.gethostname()  # Hostname
            # socket.getaddrinfo(socket.gethostname(), 0, flags=socket.AI_CANONNAME)[0][3]  # Canonical hostname  # noqa E501
            # socket.getaddrinfo(socket.gethostname(), 0, 0, 0, 0, socket.AI_CANONNAME)[0][3]  # Same same but different  # noqa E501
            # socket.gethostbyname(socket.gethostname())  # IP-assress
            self.ioc.add('boot', lambda self: Starter(
                ).boot_server('', ioc=self))
            boot = self.ioc.boot

    def _finalize(self):
        self._applog.info('Shutting down server.')
        self._applog.info('Server quitting.')

    def run(self):
        """Run the server applications main loop."""
        self._applog.info('-------- STARTING SERVER--------')

        self._initialize()
        try:
            asyncio.get_event_loop().run_forever()
        except KeyboardInterrupt:
            pass
        self._finalize()

        self._applog.info('-------- EXITING SERVER--------')
