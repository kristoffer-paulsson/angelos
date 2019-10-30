# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
Environment and configuration variables for the server.

The difference between environmental and configurational variables are how they
are being used. Environmental variables are globally available values that
might effect the runtime of the software. Configurational variables in
particular are used to configure services available from the IoC container.
"""

from libangelos.const import Const

"""Environment default values."""
ENV_DEFAULT = {"name": "Logo"}

"""Environment immutable values."""
ENV_IMMUTABLE = {}

"""Configuration default values"""
CONFIG_DEFAULT = {}

"""Configuration immutable values"""
CONFIG_IMMUTABLE = {
    "state": [
        {"name": "running"},
        {"name": "boot", "blocking": ("serving",), "depends": ("running",)},
        {"name": "serving", "depends": ("running",), "switches": ("boot",)},
        {"name": "nodes", "depends": ("serving",)},
        {"name": "hosts", "depends": ("serving",)},
        {"name": "clients", "depends": ("serving",)},
    ],
    "logger": {
        "version": 1,
        "formatters": {
            "default": {
                "format": "%(asctime)s %(name)s:%(levelname)s %(message)s",
                "datefmt": "%Y-%m-%d %H:%M:%S",
            },
            "console": {"format": "%(levelname)s %(message)s"},
        },
        "filters": {"default": {"name": ""}},
        "handlers": {
            "default": {
                "class": "logging.FileHandler",
                "filename": "angelos.log",
                "mode": "a+",
                "level": "INFO",
                "formatter": "default",
                "filters": [],
            },
            "console": {
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stdout",
                "level": "ERROR",
                "formatter": "console",
                "filters": [],
            },
        },
        "loggers": {
            Const.LOG_ERR: {  # LOG_ERR is used to log system errors
                "level": "INFO",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            Const.LOG_APP: {  # LOG_APP is used to log system events
                "level": "INFO",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            Const.LOG_BIZ: {  # LOG_BIZ is used to log business events
                "level": "INFO",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            "asyncio": {  # 'asyncio' is used to log business events
                "level": "WARNING",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
        },
        "root": {
            "level": "INFO",
            "filters": [],
            "handlers": ["console", "default"],
        },
        # 'incrementel': False,
        "disable_existing_loggings": True,
    },
}
