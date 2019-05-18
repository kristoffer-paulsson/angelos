# cython: language_level=3
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

    A_TYPE_BEARER           Archive type for courier data.
    A_TYPE_SEED             Archive type for seed data.
    A_TYPE_ARCHIVE          Archive type for general fs data.

    A_ROLE_PRIMARY          Current node has a primary role in the domain
    A_ROLE_BACKUP           Current node has a backup role in the domain

    A_USE_VAULT             Archive used as vault
    A_USE_HOME              Archive used as an encrypted home directory
    A_USE_MAIL              Archive used as intrachurch mail routing pool
    A_USE_POOL              Archive used as public document pool
    A_USE_FTP               Archive used as encrypted ftp file system
    A_USE_ROUTING           Archive used as interchurch mail routing pool

    CNL_VAULT               Vault file path
    CNL_HOME                Encrypted home directory file path
    CNL_MAIL                Mail routing pool file path
    CNL_POOL                Public document pool file path
    CNL_FTP                 Encrypted ftp file path
    CNL_ROUTING             Mail routing pool file path

    LOG_ERR                 Logger for technical error messages
    LOG_APP                 Logger for application related events
    LOG_BIZ                 Logger for business transactions

    """

    A_TYPE_PERSON_CLIENT = ord(b'p')
    A_TYPE_PERSON_SERVER = ord(b'P')
    A_TYPE_MINISTRY_CLIENT = ord(b'm')
    A_TYPE_MINISTRY_SERVER = ord(b'M')
    A_TYPE_CHURCH_CLIENT = ord(b'c')
    A_TYPE_CHURCH_SERVER = ord(b'C')

    A_TYPE_BEARER = ord(b'b')
    A_TYPE_SEED = ord(b's')
    A_TYPE_ARCHIVE = ord(b'a')

    A_ROLE_PRIMARY = ord(b'p')
    A_ROLE_BACKUP = ord(b'b')

    A_USE_VAULT = ord(b'v')
    A_USE_HOME = ord(b'h')
    A_USE_MAIL = ord(b'm')
    A_USE_POOL = ord(b'p')
    A_USE_FTP = ord(b'f')
    A_USE_ROUTING = ord(b'r')

    CNL_VAULT = 'vault.ar7.cnl'
    CNL_HOME = 'home.ar7.cnl'
    CNL_MAIL = 'mail.ar7.cnl'
    CNL_POOL = 'pool.ar7.cnl'
    CNL_FTP = 'ftp.ar7.cnl'
    CNL_ROUTING = 'routing.ar7.cnl'

    LOG_ERR = 'err'
    LOG_APP = 'app'
    LOG_BIZ = 'biz'

    OPT_LISTEN = ['localhost', 'loopback', 'hostname', 'domain', 'ip', 'any']

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

    ARCH_BLK_1 = 227
    ARCH_BLK_2 = 454
    ARCH_BLK_4 = 908
