"""Docstring"""
import collections
import threading
from .utils import Util
from .error import Error


Message = collections.namedtuple('Message', 'sender recipient message data')


class Events:
    """Docstring"""
    def __init__(self):
        self.__lock = threading.Lock()
        self.__queues = {}

    def add(self, name):
        """Docstring"""
        with self.__lock:
            if name in self.__queues:
                raise Util.exception(
                    Error.EVENT_ADDRESS_TAKEN, {'name': name})
            self.__queues[name] = collections.deque(maxlen=10)

    def remove(self, name):
        """Docstring"""
        with self.__lock:
            if name not in self.__queues:
                raise Util.exception(
                    Error.EVENT_ADDRESS_REMOVED, {'name': name})
            del self.__queues[name]

    def send(self, message):
        """Docstring"""
        Util.is_type(message, Message)
        with self.__lock:
            if message.recipient not in self.__queues:
                raise Util.exception(
                    Error.EVENT_ADDRESS_MISSING,
                    {'recipient', message.recipient})
            self.__queues[message.recipient].appendleft(message)

    def receive(self, name):
        """Docstring"""
        Util.is_type(name, str)
        with self.__lock:
            if name not in self.__queues:
                raise Util.exception(
                    Error.EVENT_ADDRESS_MISSING, {'recipient', name})
            try:
                return self.__queues[name].pop()
            except IndexError:
                return None
