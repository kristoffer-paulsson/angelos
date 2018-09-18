'''
All common data and variables to be incorporated in the server  binary
'''

from ..const import Const
from ..utils import Util

DEFAULT = {
    'runtime': {
        'root': Util.app_dir() + '/clientroot',
        'mode': Const.R_MODE_DEV,
        'type': Const.R_TYPE_CLIENT,
        'role': Const.R_ROLE_NORMAL,
        'platform': Const.R_PLATFORM_ANDROID
    },
    'configured': True
}

IMMUTABLE = {
    'logger': {
        'version': 1,
        'formatters': {
            'default': {
                'format': '%(asctime)s %(name)s:%(levelname)s %(message)s',
                'datefmt': '%Y-%m-%d %H:%M:%S',
            },
            'console': {
                'format': '%(levelname)s %(message)s',
            }
        },
        'filters': {
            'default': {
                'name': ''
            }
        },
        'handlers': {
            'default': {
                'class': 'logging.FileHandler',
                'filename': 'logo.log',
                'mode': 'a+',
                'level': 'INFO',
                'formatter': 'default',
                'filters': []
            },
            'console': {
                'class': 'logging.StreamHandler',
                'stream': 'ext://sys.stdout',
                'level': 'ERROR',
                'formatter': 'console',
                'filters': []
            },
        },
        'loggers': {
            Const.LOG_ERR: {  # LOG_ERR is used to log system errors
                'level': 'INFO',
                # 'propagate': None,
                'filters': [],
                'handlers': ['default'],
            },
            Const.LOG_APP: {  # LOG_APP is used to log system events
                'level': 'INFO',
                # 'propagate': None,
                'filters': [],
                'handlers': ['default'],
            },
            Const.LOG_BIZ: {  # LOG_BIZ is used to log business events
                'level': 'INFO',
                # 'propagate': None,
                'filters': [],
                'handlers': ['default'],
            },
            'asyncio': {  # 'asyncio' is used to log business events
                'level': 'WARNING',
                # 'propagate': None,
                'filters': [],
                'handlers': ['default'],
            },
            'kivy': {  # 'kivy' is used to log business events
                'level': 'WARNING',
                # 'propagate': None,
                'filters': [],
                'handlers': ['default'],
            }
        },
        'root': {
            'level': 'INFO',
            'filters': [],
            'handlers': ['console', 'default'],
        },
        # 'incrementel': False,
        # 'disable_existing_loggings': True
    },
}
