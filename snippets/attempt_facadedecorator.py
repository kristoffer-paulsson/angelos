from libangelos.facade.base import BaseFacade


class Facade(BaseFacade):
    pass


class EntityFacadeMixin:
    """Abstract baseclass for Entities FacadeMixin's."""

    pass


class PersonFacadeMixin(EntityFacadeMixin):
    """Mixin for a Person Facade."""

    def __init__(self):
        """Initialize facade."""
        EntityFacadeMixin.__init__(self)


class MinistryFacadeMixin(EntityFacadeMixin):
    """Mixin for a Ministry Facade."""

    def __init__(self):
        """Initialize facade."""
        EntityFacadeMixin.__init__(self)


class ChurchFacadeMixin(EntityFacadeMixin):
    """Mixin for a Church Facade."""

    def __init__(self):
        """Initialize facade."""
        EntityFacadeMixin.__init__(self)


class TypeFacadeMixin:
    """Abstract baseclass for type FacadeMixin's."""

    ARCHIVES = (VaultArchive,)
    APIS = ()
    DATAS = ()
    TASKS = ()

    def __init__(self):
        """Initialize facade."""
        pass


class ServerFacadeMixin(TypeFacadeMixin):
    """Mixin for a Server Facade."""

    ARCHIVES = (MailArchive, PoolArchive, RoutingArchive, FtpArchive) + TypeFacadeMixin.ARCHIVES
    APIS = () + TypeFacadeMixin.APIS
    DATAS = () + TypeFacadeMixin.DATAS
    TASKS = () + TypeFacadeMixin.TASKS

    def __init__(self):
        """Initialize facade."""
        TypeFacadeMixin.__init__(self)


class ClientFacadeMixin(TypeFacadeMixin):
    """Mixin for a Church Facade."""

    ARCHIVES = (HomeArchive, ) + TypeFacadeMixin.ARCHIVES
    APIS = () + TypeFacadeMixin.APIS
    DATAS = () + TypeFacadeMixin.DATAS
    TASKS = () + TypeFacadeMixin.TASKS

    def __init__(self):
        """Initialize facade."""
        TypeFacadeMixin.__init__(self)


class PersonClientFacade(Facade, ClientFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity in a client."""

    INFO = (Const.A_TYPE_PERSON_CLIENT,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class PersonServerFacade(Facade, ServerFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity as a server."""

    INFO = (Const.A_TYPE_PERSON_SERVER,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class MinistryClientFacade(Facade, ClientFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity in a client."""

    INFO = (Const.A_TYPE_MINISTRY_CLIENT,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class MinistryServerFacade(Facade, ServerFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity as a server."""

    INFO = (Const.A_TYPE_MINISTRY_SERVER,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class ChurchClientFacade(Facade, ClientFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity in a client."""

    INFO = (Const.A_TYPE_CHURCH_CLIENT,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)


class ChurchServerFacade(Facade, ServerFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity as a server."""

    INFO = (Const.A_TYPE_CHURCH_SERVER,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)


if "__main__" in __name__:
    home_dir
    facade = Facade.setup()
