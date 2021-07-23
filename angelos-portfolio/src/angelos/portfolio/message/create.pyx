# cython: language_level=3, linetrace=True
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
import datetime
import uuid
from typing import Union, List

from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.envelope import Envelope
from angelos.document.messages import Instant, MESSAGE_EXPIRY_PERIOD, Note, Mail, Attachment, Share, Report
from angelos.document.utils import Helper as DocumentHelper
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, Portfolio
from angelos.portfolio.policy import IssuePolicy
from angelos.portfolio.utils import MimeTypes, Definitions


# TODO: Make an overhaul


class MailBuilder:
    """Mail building class."""

    MIME = ("application/octet-stream",)

    def __init__(self, sender: PrivatePortfolio, mail: Mail):
        """Init the mail builder"""
        self.__sender = sender
        self.__mail = mail

    def message(self, subject: str, body: str, reply: Union[Mail, uuid.UUID] = None):
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

    def add(self, name: str, data: bytes, mime: str):
        """Add an attachment to the mail."""
        attachement = Attachment(nd={"name": name if name else "Unnamed", "mime": mime, "data": data})
        attachement.validate()
        self.__mail.attachments.append(attachement)

        return self

    def done(self) -> Mail:
        """Finalize the mail message."""
        self.__mail._fields["signature"].redo = True
        self.__mail.signature = None
        self.__mail.expires = datetime.date.today() + datetime.timedelta(MESSAGE_EXPIRY_PERIOD)
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

        return Crypto.sign(self.__mail, self.__sender)


class ShareBuilder(MailBuilder):
    def share(self, portfolio: Portfolio) -> Share:
        """Create a Share message containing documents to be shared."""
        for doc in portfolio.documents():
            self.add(
                doc.__class__.__name__,
                DocumentHelper.serialze(doc),
                ShareBuilder.MIME[0]
            )

        return self.done()


class ReportBuilder(MailBuilder):

    def report(
        self, message: Union[Mail, Instant], envelope: Envelope,
        claims: List[str], msg: str
    ) -> Report:
        """Create a Share message containing documents to be shared."""
        if len(claims) < 1 or len(claims) > 3:
            raise ValueError("At least 1 and most 3 claims.")

        for doc in set(message, envelope):
            self.add(
                doc.__class__.__name__,
                DocumentHelper.serialze(doc),
                ReportBuilder.MIME
            )

        text = "\n".join(["{0}: {1}".format(
            claim, Definitions.REPORT[claim]) for claim in claims])

        self.message(
            "Claims: {0}".format(", ".join(claims)),
            "MESSAGE:\n{0}\n\nCLAIMS:\n{1}".format(
                msg if msg else "n/a", text
            ),
        )
        return self.done()


class CreateInstant(IssuePolicy, PolicyPerformer, PolicyMixin):

    def __init__(self):
        super().__init__()
        self._data = None
        self._mime = None
        self._reply = None

    def _setup(self):
        self._document = None

    def _clean(self):
        self._portfolio = None
        self._owner = None
        self._data = None
        self._mime = None
        self._reply = None

    def apply(self) -> bool:
        if self._mime not in list(map(str, MimeTypes)):
            raise ValueError("Unsupported mime-type for instant messages.")

        self._document = Instant(nd={
            "owner": self._owner.entity.id,
            "issuer": self._portfolio.entity.id,
            "mime": self._mime,
            "body": self._data if self._data else b"",
            "reply": self._reply.id if self._reply else None,
            "expires": datetime.date.today() + datetime.timedelta(MESSAGE_EXPIRY_PERIOD),
            "posted": datetime.datetime.now(),
        })

        self._document = Crypto.sign(self._document, self._portfolio)
        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
        ]):
            raise PolicyException()
        return True

    @policy(b'I', 0, "Instant:Create")
    def perform(
        self, sender: PrivatePortfolio, recipient: Portfolio,
        data: bytes, mime: str, reply: Instant = None
    ) -> Instant:
        self._portfolio = sender
        self._owner = recipient
        self._data = data
        self._mime = mime
        self._reply = reply
        self._applier()
        return self._document


class CreateNote(IssuePolicy, PolicyPerformer, PolicyMixin):
    def __init__(self):
        super().__init__()
        self._body = None
        self._reply = None

    def _setup(self):
        self._document = None

    def _clean(self):
        self._portfolio = None
        self._owner = None
        self._data = None
        self._reply = None

    def apply(self) -> bool:
        self._document = Note(nd={
            "owner": self._owner.entity.id,
            "issuer": self._portfolio.entity.id,
            "body": self._body if self._body else "",
            "reply": self._reply.id if self._reply else None ,
            "expires": datetime.date.today() + datetime.timedelta(MESSAGE_EXPIRY_PERIOD),
            "posted": datetime.datetime.now(),
        })

        self._document = Crypto.sign(self._document, self._portfolio)
        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
        ]):
            raise PolicyException()
        return True

    @policy(b'I', 0, "Node:Create")
    def perform(self, sender: PrivatePortfolio, recipient: Portfolio, body: str, reply: Note = None) -> Note:
        """Compose a mail by using a mailbuilder."""
        self._portfolio = sender
        self._owner = recipient
        self._body = body
        self._reply = reply
        self._applier()
        return self._document


class CreateMail(IssuePolicy, PolicyPerformer, PolicyMixin):

    def __init__(self):
        super().__init__()

    def _setup(self):
        self._document = None

    def _clean(self):
        self._owner = None

    def apply(self) -> bool:
        self._document = Mail(nd={
            "owner": self._owner.entity.id,
            "issuer": self._portfolio.entity.id
        })

        return True

    @policy(b'I', 0, "Mail:Create")
    def perform(self, sender: PrivatePortfolio, recipient: Portfolio) -> MailBuilder:
        self._portfolio = sender
        self._owner = recipient
        self._applier()
        return MailBuilder(self._portfolio, self._document)


class CreateShare(IssuePolicy, PolicyPerformer, PolicyMixin):
    def __init__(self):
        super().__init__()

    def _setup(self):
        self._document = None

    def _clean(self):
        self._owner = None

    def apply(self) -> bool:
        self._document = Share(nd={
            "owner": self._owner.entity.id,
            "issuer": self._portfolio.entity.id
        })

        return True

    @policy(b'I', 0, "Share:Create")
    def perform(self, sender: PrivatePortfolio, recipient: Portfolio) -> ShareBuilder:
        self._portfolio = sender
        self._owner = recipient
        self._applier()
        return ShareBuilder(self._portfolio, self._document)


class CreateReport(IssuePolicy, PolicyPerformer, PolicyMixin):
    def __init__(self):
        super().__init__()

    def _setup(self):
        self._document = None

    def _clean(self):
        self._owner = None

    def apply(self) -> bool:
        self._document = Report(nd={
            "owner": self._portfolio.entity.id,
            "issuer": self._owner.entity.id
        })
        return True

    @policy(b'I', 0, "Report:Create")
    def perform(self, sender: PrivatePortfolio, recipient: Portfolio) -> ReportBuilder:
        self._portfolio = sender
        self._owner = recipient
        self._applier()
        return ReportBuilder(self._portfolio, self._document)