# cython: language_level=3
"""Generate and verify messages."""
import enum
import datetime
import pickle

from ..utils import Util
from .crypto import Crypto
from .policy import SignPolicy
from ..document.entities import Person, Ministry, Church, Keys
from ..document.messages import Message, Instant, Note, Mail, Report, Share
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

        MP4_A = 'audio/mp4'
        MPEG_A = 'audio/mpeg'
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

        if envelope.header[-1].op == Header.Op.RECEIVE:
            raise RuntimeError('Envelope already received.')

        self._add_header(envelope, Header.Op.ROUTE)
        return envelope

    def wrap(self, message, receiver, keys):
        """Wrap a message in an envelope."""
        Util.is_type(message, (Note, Instant, Mail, Share, Report))
        Util.is_type(receiver, (Person, Ministry, Church))
        Util.is_type(keys, Keys)

        message = Crypto.sign(message, self.entity, self.privkeys, self.keys)
        message.validate()

        envelope = Envelope(nd={
            'owner': message.owner,
            'message': Crypto.conceal(
                pickle.dumps(message), self.entity,
                self.privkeys, receiver, keys),
        })

        envelope = Crypto.sign(envelope, self.entity, self.privkeys, self.keys)
        envelope.validate()

        return envelope

    def open(self, envelope, sender, keys):
        """Open an envelope and unveil the message."""
        Util.is_type(envelope, Envelope)
        Util.is_type(sender, (Person, Ministry, Church))
        Util.is_type(keys, Keys)

        envelope = Crypto.verify(envelope, sender, keys)
        envelope.validate()

        message = pickle.loads(Crypto.unveil(
            envelope.message, self.entity, self.privkeys, sender, keys))

        message = Crypto.verify(message, sender, keys)
        message.validate()

        return message

    def _add_header(self, envelope, operation):
        if operation not in list(map(Header.Op)):
            raise ValueError('Illegal header operation.')

        header = Header(nd={
            'op': operation,
            'issuer': self.entity,
            'timestamp': datetime.datetime.now()
        })

        header = Crypto.sign_header(
            envelope, header, self.entity, self.privkeys, self.leys)

        envelope.header.append(header)
