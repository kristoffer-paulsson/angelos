from ..const import Const
from ..events import Message


class Messages:
    DO_SETUP = 100

    @staticmethod
    def setup(sender, entity, type):
        """Sends a message to the Backend, running setup routine."""
        return Message(
            sender=sender,
            recipient=Const.W_BACKEND_NAME,
            message=Messages.DO_SETUP,
            data={'entity': entity, 'type': type}
        )
