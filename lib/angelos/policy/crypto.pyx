# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Conceal/unveal algorithms."""
import libnacl
import datetime

from typing import Set

from ..utils import Util
from ..document import Document, Keys, Envelope, Header
from ..document.document import UpdatedMixin
from .portfolio import Portfolio, PrivatePortfolio


class Crypto:
    """Conceal/unveil policy."""

    @staticmethod
    def _document_data(document: Document, exclude: list = []) -> bytes:
        new_dict = {}
        exclude += ["issuer", "signature"]

        for k, v in document.export_bytes().items():
            if k not in exclude:
                new_dict[k] = v

        return Crypto._dict_data(new_dict)

    @staticmethod
    def _list_data(_list: list) -> bytes:
        stream = bytes()
        for item in _list:
            if isinstance(item, dict):
                stream += Crypto._dict_data(item)
            elif isinstance(item, (bytes, bytearray)):
                stream += item
            else:
                Util.is_type(item, (bytes, bytearray, type(None)))

        return stream

    @staticmethod
    def _dict_data(_dict: dict) -> bytes:
        stream = bytes()
        for field, data in sorted(_dict.items()):
            stream += field.encode()
            if isinstance(data, list):
                stream += Crypto._list_data(data)
            elif isinstance(data, dict):
                stream += Crypto._dict_data(data)
            elif isinstance(data, (bytes, bytearray)):
                stream += data
            else:
                Util.is_type(data, (bytes, bytearray, type(None)))

        return stream

    @staticmethod
    def _overlap(document: Document, keys: Keys) -> bool:
        """
        Calculate key lifetime accuracy to document.

        The document created date or updated date should be within the key
        lifetime.
        """
        if document is UpdatedMixin:
            if document.updated:
                return keys.created <= document.updated and (
                    keys.expires >= document.updated
                )
            else:
                return keys.created <= document.created and (
                    keys.expires >= document.created
                )
        else:
            return keys.created <= document.created and (
                keys.expires >= document.created
            )

    @staticmethod
    def _latestkeys(keys: Set[Keys]) -> Keys:
        """Return latest key from set."""
        return sorted(keys, key=lambda doc: doc.created, reverse=True)[0]

    @staticmethod
    def conceal(
        data: bytes, sender: PrivatePortfolio, receiver: Portfolio
    ) -> bytes:
        """Conceal data."""
        keys = Crypto._latestkeys(receiver.keys)

        if not (sender.privkeys.issuer == sender.entity.id):
            raise RuntimeError(
                'PrivateKeys "issuer" and sender "id" doesn\'t match'
            )

        if not (keys.issuer == receiver.entity.id):
            raise RuntimeError(
                'Keys "issuer" and receiver "id" doesn\'t match'
            )

        today = datetime.date.today()

        if today > sender.entity.expires:
            raise RuntimeError("The sending entity has expired")

        if today > sender.privkeys.expires:
            raise RuntimeError("The concealing keys has expired")

        if today > receiver.entity.expires:
            raise RuntimeError("The receiving entity has expired")

        if today > keys.expires:
            raise RuntimeError("The receiving keys has expired")

        return libnacl.public.Box(sender.privkeys.secret, keys.public).encrypt(
            data
        )

    @staticmethod
    def unveil(
        data: bytes, receiver: PrivatePortfolio, sender: Portfolio
    ) -> bytes:
        """Unveil data."""
        keys = Crypto._latestkeys(sender.keys)

        if not (receiver.privkeys.issuer == receiver.entity.id):
            raise RuntimeError(
                'PrivateKeys "issuer" and receiver "id" doesn\'t match'
            )

        if not (keys.issuer == sender.entity.id):
            raise RuntimeError('Keys "issuer" and sender "id" doesn\'t match')

        today = datetime.date.today()

        if today > receiver.entity.expires:
            raise RuntimeError("The receiving entity has expired")

        if today > receiver.privkeys.expires:
            raise RuntimeError("The receiving keys has expired")

        if today > sender.entity.expires:
            raise RuntimeError("The sending entity has expired")

        if today > keys.expires:
            raise RuntimeError("The concealing keys has expired")

        return libnacl.public.Box(
            receiver.privkeys.secret, keys.public
        ).decrypt(data)

    @staticmethod
    def sign(
        document: Document,
        signer: PrivatePortfolio,
        exclude=[],
        multiple=False,
    ) -> Document:
        """Main document signing algorithm."""
        keys = Crypto._latestkeys(signer.keys)

        if not (document.issuer == keys.issuer == signer.entity.id):
            raise RuntimeError(
                'Document/Keys "issuer" or Entity "id" doesn\'t match'
            )

        today = datetime.date.today()

        if today > signer.entity.expires:
            raise RuntimeError("The signing entity has expired")

        if today > keys.expires:
            raise RuntimeError("The verifying keys has expired")

        if not multiple and document.signature:
            raise RuntimeError("Document already signed")

        if multiple and not document._fields["signature"].multiple:
            raise RuntimeError(
                "This document doesn't support multiple signatures"
            )

        data = bytes(signer.entity.id.bytes) + Crypto._document_data(
            document, exclude
        )
        signature = libnacl.sign.Signer(signer.privkeys.seed).signature(data)

        if multiple:
            if not document.signature:
                document.signature = [signature]
            else:
                document.signature.append(signature)
        else:
            document.signature = signature
        document._fields["signature"].redo = False

        return document

    @staticmethod
    def verify(document: Document, signer: Portfolio, exclude=[]) -> bool:
        """Main document verifying algorithm."""

        for keys in sorted(
            signer.keys, key=lambda doc: doc.created, reverse=True
        ):
            if not Crypto._overlap(document, keys):
                continue

            if not (document.issuer == keys.issuer == signer.entity.id):
                raise RuntimeError(
                    "Document/Keys issuer or Entity id doesn't match"
                )
            data = bytes(document.issuer.bytes) + Crypto._document_data(
                document, exclude
            )
            verifier = libnacl.sign.Verifier(keys.verify.hex())

            if isinstance(document.signature, list):
                for signature in document.signature:
                    try:
                        verifier.verify(signature + data)
                        return True
                    except ValueError:
                        pass
            else:
                try:
                    verifier.verify(document.signature + data)
                    return True
                except ValueError:
                    pass

        return False

    @staticmethod
    def sign_header(
        envelope: Envelope, header: Header, signer: PrivatePortfolio
    ) -> Header:
        """Sign envelope header"""
        keys = Crypto._latestkeys(signer.keys)

        if not (header.issuer == keys.issuer == signer.entity.id):
            raise RuntimeError(
                'Header/Keys "issuer" or Entity "id" doesn\'t match'
            )

        today = datetime.date.today()
        if today > signer.entity.expires:
            raise RuntimeError("The signing entity has expired")

        if today > keys.expires:
            raise RuntimeError("The verifying keys has expired")

        if header.signature:
            raise RuntimeError("Document already signed")

        if len(envelope.header):
            old_signature = envelope.header[-1].signature
        else:
            old_signature = envelope.signature

        data = (
            old_signature
            + bytes(signer.entity.id.bytes)
            + Crypto._document_data(header)
        )
        signature = libnacl.sign.Signer(signer.privkeys.seed).signature(data)

        header.signature = signature
        return header

    @staticmethod
    def verify_header(
        envelope: Envelope, header_no: int, signer: Portfolio
    ) -> bool:
        """Verify envelope header."""
        header = envelope.header[header_no - 1]

        if header_no - 2 > 0:
            old_signature = envelope.header[header_no - 1]
        else:
            old_signature = envelope.signature

        data = (
            old_signature
            + bytes(signer.entity.id.bytes)
            + Crypto._document_data(header)
        )

        for keys in sorted(
            signer.keys, key=lambda doc: doc.created, reverse=True
        ):
            if not (header.issuer == keys.issuer == signer.entity.id):
                raise RuntimeError(
                    "Header/Keys issuer or Entity id doesn't match"
                )

            verifier = libnacl.sign.Verifier(keys.verify.hex())

            try:
                verifier.verify(header.signature + data)
                return True
            except ValueError:
                pass

        return False
