#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""Generate and verify messages."""
import enum
import datetime
import uuid

from typing import List, Union

from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.policy import Policy
from angelos.lib.policy.portfolio import PrivatePortfolio, Portfolio, PortfolioPolicy
from angelos.document.types import MessageT
from angelos.document.messages import Instant, Note, Mail, Report, Share, Attachment
from angelos.document.envelope import Envelope, Header
from angelos.common.utils import Util
from angelos.lib.error import Error

REPORT_TEXT = {
    "Unsolicited": "Unwanted messages you do not wish to receive.",
    "Spam": "Unsolicited advertisement.",
    "Suspicious": "Professional messages that seem to be deceptive or fraudulent.",  # noqa E501
    "Harmful": "Promotion of behaviors or actions which harmful if carried out.",  # noqa E501
    "Defamation": "A message which content is defaming or slanderous towards someone.",  # noqa E501
    "Offensive": "A message which content is detestable or repulsive.",
    "Hateful": "A message that is malicious or insulting and spreads hate.",
    "Sedition": "Sedition to mischief and spread hate or commit crimes.",
    "Harassment": "A message is considered to be harassment or stalking.",
    "Menace": "A message is intimidating and menacing or contains direct threats.",  # noqa E501
    "Blackmail": "A message that intimidates you to conform to demands.",
    "Solicitation": "Solicitation for criminal purposes.",
    "Conspiracy": "Conspiracy to commit a crime.",
    "Graphic": "Undesirable graphic content.",
    "Adult": "Mature content of sexual nature.",
}


class MimeTypes(enum.Enum):
    TEXT = "text/plain"
    MARKDOWN = "text/markdown"
    HTML = "text/html"
    RTF = "text/rtf"
    VCARD = "text/vcard"
    CALENDAR = "text/calendar"

    JPEG = "image/jpeg"
    WEBP = "image/webp"
    PNG = "image/png"
    TIFF = "image/tiff"
    BMP = "image/bmp"

    MP4_A = "audio/mp4"
    MPEG_A = "audio/mpeg"
    AAC = "audio/aac"
    WEBM = "audio/webm"
    VORBIS = "audio/vorbis"

    MP4 = "video/mp4"
    MPEG = "video/mpeg"
    QUICKTIME = "video/quicktime"
    H261 = "video/h261"
    H263 = "video/h263"
    H264 = "video/h264"
    H265 = "video/h265"
    OGG = "video/ogg"

    ZIP = "application/zip"
    _7Z = "application/x-7z-compressed"


class ReportType(enum.Enum):
    UNSOLICITED = "Unsolicited"
    SPAM = "Spam"
    SUSPICIOUS = "Suspicious"
    HARMFUL = "Harmful"
    DEFAMATION = "Defamation"
    OFFENSIVE = "Offensive"
    HATEFUL = "Hateful"
    SEDITION = "Sedition"
    HARASSMENT = "Harassment"
    MENACE = "Menace"
    BLACKMAIL = "Blackmail"
    SOLICITATION = "Solicitation"
    CONSPIRACY = "Conspiracy"
    GRAPHIC = "Graphic"
    ADULT = "Adult"


class MailBuilder:
    """Mail building class."""

    def __init__(self, sender: PrivatePortfolio, mail: Mail):
        """Init the mail builder"""
        self.__sender = sender
        self.__mail = mail

    def message(
        self, subject: str, body: str, reply: Union[Mail, uuid.UUID] = None
    ):  # -> MailBuilder:
        """Add mail body, subject and reply-to."""
        self.__mail.subject = subject if subject else ""
        self.__mail.body = body if body else ""

        if isinstance(reply, Mail):
            self.__mail.reply = reply.id
        elif isinstance(reply, uuid.UUID):
            self.__mail.reply = reply
        else:
            self.__mail.reply = None

        return self

    def add(self, name: str, data: bytes, mime: str):  # -> MailBuilder:
        """Add an attachment to the mail."""
        attachement = Attachment(nd={"name": name if name else "Unnamed", "mime": mime, "data": data})
        attachement.validate()
        self.__mail.attachments.append(attachement)

        return self

    def done(self) -> Mail:
        """Finalize the mail message."""
        self.__mail._fields["signature"].redo = True
        self.__mail.signature = None
        self.__mail.expires = datetime.date.today() + datetime.timedelta(30)
        self.__mail.posted = datetime.datetime.utcnow()

        mail = Crypto.sign(self.__mail, self.__sender)
        mail.validate()

        return mail

    def draft(self) -> Mail:
        """Export draft mail document"""
        self.__mail._fields["signature"].redo = True
        self.__mail.signature = None
        self.__mail.expires = datetime.date.today() + datetime.timedelta(365)
        self.__mail.posted = datetime.datetime(1, 1, 1, 1, 1, 1)

        mail = Crypto.sign(self.__mail, self.__sender)

        return mail


class ShareBuilder(MailBuilder):
    def share(self, portfolio: Portfolio) -> Share:
        """Create a Share message containing documents to be shared."""
        mime = "application/octet-stream"
        issuer, owner = portfolio.to_sets()
        for doc in issuer | owner:
            self.add(
                doc.__class__.__name__, PortfolioPolicy.serialze(doc), mime
            )

        return self.done()


class ReportBuilder(MailBuilder):
    """Build a report message."""

    def report(
        self, message: MessageT, envelope: Envelope,
        claims: List[str], msg: str
    ) -> Report:
        """Create a Share message containing documents to be shared."""
        if len(claims) < 1 or len(claims) > 3:
            raise ValueError("At least 1 and most 3 claims.")

        mime = "application/octet-stream"
        for doc in set(message, envelope):
            self.add(
                doc.__class__.__name__, PortfolioPolicy.serialze(doc), mime
            )

        text = "\n".join(
            ["{0}: {1}".format(claim, REPORT_TEXT[claim]) for claim in claims]
        )

        self.message(
            "Claims: {0}".format(", ".join(claims)),
            "MESSAGE:\n{0}\n\nCLAIMS:\n{1}".format(
                msg if msg else "n/a", text
            ),
        )
        return self.done()


class MessagePolicy(Policy):
    """Generate messages."""

    @staticmethod
    def instant(
        sender: PrivatePortfolio,
        recipient: Portfolio,
        data: bytes,
        mime: str,
        reply: Instant = None,
    ) -> Instant:
        """Issue an instant message."""
        if mime not in list(map(str, MimeTypes)):
            raise ValueError("Unsupported mime-type for instant messages.")

        instant = Instant(
            nd={
                "owner": recipient.entity.id,
                "issuer": sender.entity.id,
                "mime": mime,
                "body": data if data else b"",
                "reply": None if not reply else reply.id,
                "expires": datetime.date.today() + datetime.timedelta(30),
                "posted": datetime.datetime.now(),
            }
        )

        instant = Crypto.sign(instant, sender.entity)
        instant.validate()

        return instant

    @staticmethod
    def note(
        sender: PrivatePortfolio,
        recipient: Portfolio,
        body: str,
        reply: Note = None,
    ) -> Note:
        """Issue a note."""
        note = Note(
            nd={
                "owner": recipient.entity.id,
                "issuer": sender.entity.id,
                "body": body if body else "",
                "reply": None if not reply else reply.id,
                "expires": datetime.date.today() + datetime.timedelta(30),
                "posted": datetime.datetime.now(),
            }
        )

        note = Crypto.sign(note, sender)
        note.validate()

        return note

    @staticmethod
    def mail(sender: PrivatePortfolio, recipient: Portfolio) -> MailBuilder:
        """Compose a mail by using a mailbuilder."""
        mail = Mail(
            nd={"owner": recipient.entity.id, "issuer": sender.entity.id}
        )
        return MailBuilder(sender, mail)

    @staticmethod
    def share(sender: PrivatePortfolio, recipient: Portfolio) -> ShareBuilder:
        """Compose a share of documents by using a mailbuilder."""
        share = Share(
            nd={"owner": recipient.entity.id, "issuer": sender.entity.id}
        )
        return ShareBuilder(sender, share)

    @staticmethod
    def report(
        sender: PrivatePortfolio, recipient: Portfolio
    ) -> ReportBuilder:
        """Compose a report by using a mailbuilder."""
        report = Report(
            nd={"owner": recipient.entity.id, "issuer": sender.entity.id}
        )
        return ReportBuilder(sender, report)


class EnvelopePolicy(Policy):
    """Envelope handling policy."""

    @staticmethod
    def route(router: PrivatePortfolio, envelope: Envelope) -> Envelope:
        """Sign an envelope header."""
        if envelope.header[-1].op == Header.Op.RECEIVE:
            raise RuntimeError("Envelope already received.")

        EnvelopePolicy._add_header(router, envelope, Header.Op.ROUTE)
        return envelope

    @staticmethod
    def wrap(
        sender: PrivatePortfolio, recipient: Portfolio, message: MessageT
    ) -> Envelope:
        """Wrap a message in an envelope."""
        Crypto.verify(message, sender)
        message.validate()

        if not (
            (message.issuer == sender.entity.id)
            and (message.owner == recipient.entity.id)
        ):
            raise ValueError(
                "Message sender and recipient not the same as on envelope."
            )

        envelope = Envelope(
            nd={
                "issuer": message.issuer,
                "owner": message.owner,
                "message": Crypto.conceal(
                    PortfolioPolicy.serialize(message), sender, recipient
                ),
                "expires": datetime.date.today() + datetime.timedelta(30),
                "posted": datetime.datetime.utcnow(),
                "header": [],
            }
        )

        envelope = Crypto.sign(envelope, sender, exclude=["header"])

        EnvelopePolicy._add_header(sender, envelope, Header.Op.SEND)
        envelope.validate()

        return envelope

    @staticmethod
    def open(
        recipient: PrivatePortfolio, sender: Portfolio, envelope: Envelope
    ) -> MessageT:
        """Open an envelope and unveil the message."""

        if not Crypto.verify(envelope, sender, exclude=["header"]):
            raise Error.exception(
                Error.POLICY_ENVELOPE_OPEN_VERIFICATION_FAILED, {
                    "envelope": envelope.id, "recipient": recipient.entity.id,
                    "sender": recipient.entity.id})

        if not envelope.validate():
            raise Error.exception(
                Error.POLICY_ENVELOPE_OPEN_VALIDATION_FAILED, {
                    "envelope": envelope.id, "recipient": recipient.entity.id,
                    "sender": recipient.entity.id})

        message = PortfolioPolicy.deserialize(
            Crypto.unveil(envelope.message, recipient, sender)
        )

        if not Crypto.verify(message, sender):
            raise Error.exception(
                Error.POLICY_ENVELOPE_OPEN_MESSAGE_VERIFICATION_FAILED, {
                    "envelope": envelope.id, "message": message.id,
                    "recipient": recipient.entity.id, "sender": recipient.entity.id})

        if not message.validate():
            raise Error.exception(
                Error.POLICY_ENVELOPE_OPEN_MESSAGE_VALIDATION_FAILED, {
                    "envelope": envelope.id, "message": message.id,
                    "recipient": recipient.entity.id, "sender": recipient.entity.id})

        return message

    @staticmethod
    def receive(recipient: PrivatePortfolio, envelope: Envelope) -> Envelope:
        """Receive the envelope when it reaches its final domain."""
        if not envelope.validate():
            return None

        if envelope.owner != recipient.entity.id:
            return None

        EnvelopePolicy._add_header(recipient, envelope, Header.Op.RECEIVE)
        return envelope

    @staticmethod
    def _add_header(
        handler: PrivatePortfolio, envelope: Envelope, operation: str
    ):
        if operation not in ("SEND", "RTE", "RECV"):
            raise ValueError("Illegal header operation.")

        header = Header(nd={
            "op": operation,
            "issuer": handler.entity.id,
            "timestamp": datetime.datetime.utcnow()
        })

        header = Crypto.sign_header(envelope, header, handler)
        envelope.header.append(header)
