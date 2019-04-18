"""All constants goes here."""


class Const:
    """
    All global constants.

    Bla bla bla

    Attributes:
    A_TYPE_PERSON_CLIENT    Archive type for PersonClientFacade
    A_TYPE_PERSON_SERVER    Archive type for PersonServerFacade
    A_TYPE_MINISTRY_CLIENT  Archive type for MinistryClientFacade
    A_TYPE_MINISTRY_SERVER  Archive type for MinistryServerFacade
    A_TYPE_CHURCH_CLIENT    Archive type for ChurchClientFacade
    A_TYPE_CHURCH_SERVER    Archive type for ChurchServerFacade

    A_ROLE_PRIMARY          Current node has a primary role in the domain
    A_ROLE_CLIENT           Current node has a backup role in the domain

    A_USE_VAULT             Archive used as vault
    A_USE_HOME              Archive used as an encrypted home directory
    A_USE_MAIL              Archive used as mail router pool
    A_USE_POOL              Archive used as public document pool
    A_USE_FTP               Archive used as encrypted ftp file system

    LOG_ERR                 Logger for technical error messages
    LOG_APP                 Logger for application related events
    LOG_BIZ                 Logger for business transactions

    """

    A_TYPE_PERSON_CLIENT = b'p'
    A_TYPE_PERSON_SERVER = b'P'
    A_TYPE_MINISTRY_CLIENT = b'm'
    A_TYPE_MINISTRY_SERVER = b'M'
    A_TYPE_CHURCH_CLIENT = b'c'
    A_TYPE_CHURCH_SERVER = b'C'

    A_ROLE_PRIMARY = b'p'
    A_ROLE_CLIENT = b'c'

    A_USE_VAULT = b'v'
    A_USE_HOME = b'h'
    A_USE_MAIL = b'm'
    A_USE_POOL = b'p'
    A_USE_FTP = b'f'

    LOG_ERR = 'err'
    LOG_APP = 'app'
    LOG_BIZ = 'biz'

    LOOP_SLEEP = 0.05

    W_SUPERV_NAME = 'Supervisor'  # Server Supervisor worker
    W_ADMIN_NAME = 'AdminServer'  # Server Admin worker
    G_CORE_NAME = 'Core'
    W_CLIENT_NAME = 'Client'  # Client main worker
    W_BACKEND_NAME = 'Backend'  # Client backend worker

    # Runtime nodes
    R_MODE_DEV = 'dev'
    R_MODE_PRODUCTION = 'prod'

    R_TYPE_SERVER = 'server'
    R_TYPE_CLIENT = 'client'

    R_ROLE_NORMAL = 'normal'
    R_ROLE_BACKUP = 'backup'

    R_PLATFORM_NIX = 'nix'
    R_PLATFORM_WIN = 'win'
    R_PLATFORM_MACOS = 'osx'
    R_PLATFORM_ANDROID = 'android'
    R_PLATFORM_IOS = 'ios'

    I_SPLASH = 'splash'
    I_DEFAULT = 'default'
    I_SETUP = 'setup'
    I_SPINNER = 'spinner'
    I_FLASH = 'flash'
