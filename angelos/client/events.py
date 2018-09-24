from ..const import Const
from ..events import Message


class Messages:
    DO_SETUP = 100
    NEW_INTERFACE = 101

    @staticmethod
    def setup(sender, entity, type):
        """Sends a message to the Backend, running setup routine."""
        return Message(
            sender=sender,
            recipient=Const.W_BACKEND_NAME,
            message=Messages.DO_SETUP,
            data={'entity': entity, 'type': type}
        )

    def interface(sender, ui):
        """Sends a message to the Backend, running setup routine."""
        return Message(
            sender=sender,
            recipient=Const.W_CLIENT_NAME,
            message=Messages.NEW_INTERFACE,
            data={'ui': ui}
        )
