import collections
import threading
from .utils import Util, FactoryInterface
from .error import Error


class Event:
    def __init__(self, sender, recipient, message, data={}):
        Util.is_type(sender, str)
        Util.is_type(recipient, str)
        Util.is_type(message, int)
        Util.is_type(data, dict)

        self.sender = sender
        self.recipient = recipient
        self.message = message
        self.data = data


class Events(FactoryInterface):
    def __init__(self):
        self.__lock = threading.Lock()
        self.__queues = {}

    def add(self, name):
        with self.__lock:
            if name in self.__queues:
                raise Util.exception(
                    Error.EVENT_ADDRESS_TAKEN, {'name': name})
            self.__queues[name] = collections.deque(maxlen=10)

    def remove(self, name):
        with self.__lock:
            if name not in self.__queues:
                raise Util.exception(
                    Error.EVENT_ADDRESS_REMOVED, {'name': name})
            del self.__queues[name]

    def send(self, event):
        Util.is_type(event, Event)
        with self.__lock:
            if event.recipient not in self.__queues:
                Error.EVENT_ADDRESS_MISSING, {'recipient', event.recipient}
            self.__queues[event.recipient].appendleft(event)

    def receive(self, name):
        Util.is_type(name, str)
        with self.__lock:
            if name not in self.__queues:
                Error.EVENT_ADDRESS_MISSING, {'recipient', name}
            try:
                return self.__queues[name].pop()
            except IndexError:
                return None
