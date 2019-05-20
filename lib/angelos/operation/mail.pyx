"""Mail related operations."""
from .operation import Operation
from ..policy.policy import SignPolicy


class MailBuilder(Operation, SignPolicy):
    """Build mail messages."""

    def __init__(self, **kwargs):
        Operation.__init__(self)
        SignPolicy.__init__(self, **kwargs)
