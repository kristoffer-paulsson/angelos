"""Generate and verify messages."""
from ..utils import Util
from .policy import SignPolicy
from .crypto import Crypto
from ..document.entities import Person, Ministry, Church
from ..document.statements import Verified, Trusted, Revoked


class CreateMessagePolicy(SignPolicy):
    
