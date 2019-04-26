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
    A_ROLE_BACKUP           Current node has a backup role in the domain
    A_ROLE_COURIES          Current archive is a courier archive
    A_ROLE_SEED             An archive used as a facade seed

    A_USE_VAULT             Archive used as vault
    A_USE_HOME              Archive used as an encrypted home directory
    A_USE_MAIL              Archive used as mail router pool
    A_USE_POOL              Archive used as public document pool
    A_USE_FTP               Archive used as encrypted ftp file system

    CNL_VAULT               Vault file path
    CNL_HOME                Encrypted home directory file path
    CNL_MAIL                Mail router pool file path
    CNL_POOL                Public document pool file path
    CNL_FTP                 Encrypted ftp file path

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

    A_ROLE_PRIMARY = ord(b'p')
    A_ROLE_BACKUP = ord(b'b')
    A_ROLE_COURIER = ord(b'c')
    A_ROLE_SEED = ord(b's')

    A_USE_VAULT = ord(b'v')
    A_USE_HOME = ord(b'h')
    A_USE_MAIL = ord(b'm')
    A_USE_POOL = ord(b'p')
    A_USE_FTP = ord(b'f')

    CNL_VAULT = 'vault.ar7.cnl'
    CNL_HOME = 'home.ar7.cnl'
    CNL_MAIL = 'mail.ar7.cnl'
    CNL_POOL = 'pool.ar7.cnl'
    CNL_FTP = 'ftp.ar7.cnl'

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
