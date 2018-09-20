import asyncio
import logging
from ..const import Const
from ..worker import Worker
from ..setup import Setup
from .events import Messages


class Backend(Worker):
    """Docstring"""
    def _initialize(self):
        logging.info('#'*10 + 'Entering ' + self.__class__.__name__ + '#'*10)
        self.ioc.message.add(Const.W_BACKEND_NAME)
        self.task(self.__backend)

    def _finalize(self):
        self.ioc.message.remove(Const.W_BACKEND_NAME)
        logging.info('#'*10 + 'Leaving ' + self.__class__.__name__ + '#'*10)

    async def __backend(self):
        logging.info('#'*10 + 'Entering __backend' + '#'*10)

        while not self._halt.is_set():

            await asyncio.sleep(0)
            event = self.ioc.message.receive(Const.W_BACKEND_NAME)

            if event is None:
                continue
            else:
                logging.info(event)

            if event.message == Messages.DO_SETUP:
                self.task(self.__setup, event.data)

        logging.info('#'*10 + 'Leaving __backend' + '#'*10)

    async def __setup(self, entity, type):
        logging.info('#'*10 + 'Entering __setup' + '#'*10)

        logging.info('{}, {}'.format(entity, type))
        su = Setup(entity=entity, type=type, db=self.ioc.entity)
        su.make_home()

        logging.info('#'*10 + 'Leaving __setup' + '#'*10)
