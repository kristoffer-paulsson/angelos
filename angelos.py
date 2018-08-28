import logging

from angelos.server.main import Server
from angelos.server.common import CONFIG
from angelos.ioc import Container


def main():
    logging.basicConfig(level=logging.DEBUG)
    app = Server(Container(CONFIG))
    app.start()


if __name__ == '__main__':
    main()
