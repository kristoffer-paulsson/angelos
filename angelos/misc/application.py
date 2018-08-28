import time
import sys

from .common import quit, logger
from .utils import Util
from .ioc import Container

"""
The application.py module containes all classes needed for the major execution
and running of the application, such as the Application class and the
Daemonizer
"""


class Application:
    """
    Main Application class. This class should be subclassed for every new
    application being made. Subclassed versions should define container methods
    for services.
    """
    def __init__(self, config={}):
        """
        Initializes the Application with application wide condig values.
        config        Dictionary of key/value pairs
        """
        Util.is_type(config, dict)
        # Apps config data
        self._ioc = Container(config)

    def _initialize(self):
        """
        Things to be done prior to main process loop execution. This method
        should be overriden.
        """
        raise NotImplementedError()

    def _finalize(self):
        """
        Things to be done after main process loop execution. This method can be
        overriden. Don't forget to stop the TaskManager.
        """
        raise NotImplementedError()

    def run(self, mode='default'):
        """
        The main loop and thread of the application. Supports Ctrl^C key
        interruption, should not be overriden. Also handles major unexpected
        exceptions and logs them as CRITICAL.
        """
        logger.info('========== Begin execution of program ==========')
        try:
            self._initialize()
            # return
            try:
                while True:
                    if quit.is_set():
                        raise KeyboardInterrupt()
                    time.sleep(1)
            except KeyboardInterrupt:
                pass
            self._finalize()
        except Exception as e:
            logger.critical(Util.format_error(
                e, 'Application.run(), Unhandled exception'), exc_info=True
            )
            sys.exit('#'*9 + ' Program crash due to internal error ' + '#'*9)
        logger.info('========== Finish execution of program ==========')
