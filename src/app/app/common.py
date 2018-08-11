import threading
import logging

from .utils import Utils, Log

"""
The common.py script is where all globally accessable variables and instances
are set up.
"""

quit = threading.Event()

debug_level = logging.DEBUG
log = Log({'path': Utils.app_dir()})

logger = log.app_logger()
bizz = log.bizz_logger()
