from angelps.server.server import Server
from angelos.server.main import CONFIG
from angelos.ioc import Container

cdef api void start():
    Server(Container(CONFIG)).start()
