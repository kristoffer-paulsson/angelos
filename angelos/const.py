"""We put all constants in here"""


class Const:
    """Docstring"""
    W_SUPERV_NAME = 'Supervisor'
    W_ADMIN_NAME = 'AdminServer'
    G_CORE_NAME = 'Core'

    LOG_ERR = 'err'
    LOG_APP = 'app'
    LOG_BIZ = 'biz'

    # Runtime nodes
    R_MODE_DEV = 'dev'
    R_MODE_PRODUCTION = 'prod'

    R_TYPE_SERVER = 'server'
    R_TYPE_CLIENT = 'client'

    R_ROLE_NORMAL = 'normal'
    R_ROLE_BACKUP = 'backup'

    R_PLATFORM_NIX = 'nix'
    R_PLATFORM_WIN = 'win'
    R_PLATFORM_MACOS = 'macos'
    R_PLATFORM_ANDROID = 'android'
    R_PLATFORM_IOS = 'ios'
