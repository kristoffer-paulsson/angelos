"""Generate and verify messages."""
import enum
import datetime

from ..utils import Util
from .crypto import Crypto
from .policy import SignPolicy
from ..document.entities import Person, Ministry, Church
from ..document.messages import Message, Instant, Note
from ..document.envelope import Envelope, Header


class CreateMessagePolicy(SignPolicy):
    """Generate messages."""

    def __init__(self, **kwargs):
        SignPolicy.__init__(self, **kwargs)
        self.message = None

    def instant(self, recepient, data, mime, reply=None):
        """Issue an instant message."""
        Util.is_type(recepient, (Person, Ministry, Church))
        Util.is_type(data, bytes)
        Util.is_type(reply, (Instant, type(None)))

        if mime not in list(map(str, CreateMessagePolicy.MimeTypes)):
            raise ValueError('Unsupported mime-type for instant messages.')

        instant = Instant(nd={
            'owner': recepient.id,
            'issuer': self.entity.id,
            'mime': mime,
            'body': data,
            'reply': reply
        })

        instant = Crypto.sign(instant, self.entity, self.privkeys, self.keys)
        instant.validate()

        self.message = instant
        return True

    def note(self, recepient, body, reply=None):
        """Issue an instant message."""
        Util.is_type(recepient, (Person, Ministry, Church))
        Util.is_type(body, str)
        Util.is_type(reply, (Message, type(None)))

        note = Note(nd={
            'owner': recepient.id,
            'issuer': self.entity.id,
            'body': body,
            'reply': reply
        })

        note = Crypto.sign(note, self.entity, self.privkeys, self.keys)
        note.validate()

        self.message = note
        return True

    class MimeTypes(enum.Enum):

        TEXT = 'text/plain'
        MARKDOWN = 'text/markdown'
        HTML = 'text/html'
        RTF = 'text/rtf'
        VCARD = 'text/vcard'
        CALENDAR = 'text/calendar'

        JPEG = 'image/jpeg'
        WEBP = 'image/webp'
        PNG = 'image/png'
        TIFF = 'image/tiff'
        BMP = 'image/bmp'

        MP4 = 'audio/mp4'
        MPEG = 'audio/mpeg'
        AAC = 'audio/aac'
        WEBM = 'audio/webm'
        VORBIS = 'audio/vorbis'

        MP4 = 'video/mp4'
        MPEG = 'video/mpeg'
        QUICKTIME = 'video/quicktime'
        H261 = 'video/H261'
        H263 = 'video/H263'
        H264 = 'video/H264'
        H265 = 'video/H265'
        OGG = 'video/ogg'

        ZIP = 'application/zip'
        _7Z = 'application/x-7z-compressed'

    class Report(enum.Enum):
        UNSOLICITED = 'Unsolicited'
        SPAM = 'Spam'
        SUSPICIOUS = 'Suspicious'
        HARMFUL = 'Harmful'
        DEFAMATION = 'Defamation'
        OFFENSIVE = 'Offensive'
        HATEFUL = 'Hateful'
        INCITEMENT = 'Incitement'
        HARASSMENT = 'Harassment'
        MENACE = 'Menace'
        BLACKMAIL = 'Blackmail'
        SOLICITATION = 'Solicitation'
        CONSPIRACY = 'Conspiracy'
        GRAPHIC = 'Graphic'
        ADULT = 'Adult'


class EnvelopePolicy(SignPolicy):
    """Envelope handling policy."""

    def route(self, envelope):
        """Sign an envelope header."""
        Util.is_type(envelope, Envelope)

    def wrap(self, message, entity, keys):
        """Wrap a message in an envelope."""

    def open(self):
        """Open a envelope and unveil the message."""

    def _add_header(self, envelope, operation):
        if operation not in list(map(Header.Op)):
            raise ValueError('Illegal header operation.')

        header = Header(nd={
            'op': operation,
            'issuer': self.entity,
            'timestamp': datetime.datetime.now()
        })

        data = operation + self.entity.id.bytes + \
            bytes(now.isoformat(), 'utf-8') + envelope.header[-1].signature

        envelope.header.append()
