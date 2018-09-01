from ..const import Const
from ..events import Event


class ServerEvent(Event):
    MESSAGE_QUIT = 1

    def __init__(self, sender, message, data={}):
        Event.__init__(self, sender, Const.W_SUPERV_NAME, message, data)
