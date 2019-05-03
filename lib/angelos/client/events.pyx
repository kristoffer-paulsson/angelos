# cython: language_level=3
"""Module docstring."""
from ..const import Const
from ..events import Message


class Messages:
    DO_SETUP = 100
    NEW_INTERFACE = 101
    MSG_FLASH = 102
    DO_PICTURE = 103

    @staticmethod
    def setup(sender, entity, type):
        """Sends a message to the Backend, running setup routine."""
        return Message(
            sender=sender,
            recipient=Const.W_BACKEND_NAME,
            message=Messages.DO_SETUP,
            data={'entity': entity, 'type': type}
        )

    @staticmethod
    def interface(sender, ui):
        """Sends a message to the Backend, running setup routine."""
        return Message(
            sender=sender,
            recipient=Const.W_CLIENT_NAME,
            message=Messages.NEW_INTERFACE,
            data={'ui': ui}
        )

    @staticmethod
    def profile_picture(sender, pixels, width):
        """Sends a message to the Backend, running setup routine."""
        return Message(
            sender=sender,
            recipient=Const.W_BACKEND_NAME,
            message=Messages.DO_PICTURE,
            data={'pixels': pixels, 'width': width}
        )

    @staticmethod
    def flash(sender, msg):
        """Sends a message to the Backend, running setup routine."""
        return Message(
            sender=sender,
            recipient=Const.W_CLIENT_NAME,
            message=Messages.MSG_FLASH,
            data={'msg': msg}
        )
