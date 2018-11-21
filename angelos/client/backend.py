import asyncio
import logging
from ..const import Const
from ..worker import Worker
from .events import Messages

from eidon.stream import EidonStream
from eidon.codec import EidonEncoder
from eidon.image import EidonImage


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

            await asyncio.sleep(Const.LOOP_SLEEP)
            event = self.ioc.message.receive(Const.W_BACKEND_NAME)

            if event is None:
                continue
            else:
                logging.info(event)

            if event.message == Messages.DO_SETUP:
                self.task(self.__setup, event.data)

            if event.message == Messages.DO_PICTURE:
                self.task(self.__picture, event.data)

        logging.info('#'*10 + 'Leaving __backend' + '#'*10)

    async def __setup(self, entity, type):
        logging.info('#'*10 + 'Entering __setup' + '#'*10)

        logging.info('{}, {}'.format(entity, type))
        self.ioc.facade.create(entity)
        await asyncio.sleep(3)
        self.ioc.message.send(
            Messages.interface(Const.W_BACKEND_NAME, Const.I_DEFAULT))

        logging.info('#'*10 + 'Leaving __setup' + '#'*10)

    async def __picture(self, pixels, width):
        logging.info('#'*10 + 'Entering __picture' + '#'*10)

        def encode(pixels, width, height):
            encoder = EidonEncoder(
                EidonImage.rgba(width, height, pixels),
                EidonStream.preferred(width, height))
            stream = encoder.run(_async=True)
            return EidonStream.dump(stream)

        print('ENCODING STARTED')
        self.ioc.facade.picture = encode(pixels, width, width)
        await asyncio.sleep(3)
        print('ENCODING DONE')
        self.ioc.message.send(
            Messages.flash(Const.W_BACKEND_NAME, 'Profile picture saved'))

        logging.info('#'*10 + 'Leaving __picture' + '#'*10)
