# cython: language_level=3
"""Module docstring."""
import libnacl
import datetime

from ..utils import Util
from ..document.document import Document
from ..document.entities import Entity, PrivateKeys, Keys


class Crypto:
    @staticmethod
    def _document_data(document, exclude=[]):
        new_dict = {}
        exclude += ['issuer', 'signature']

        for k, v in document.export_bytes().items():
            if k not in exclude:
                new_dict[k] = v

        return Crypto._dict_data(new_dict)

    def _list_data(_list):
        stream = bytes()
        for item in sorted(_list):
            if isinstance(item, dict):
                stream += Crypto._dict_data(item)
            elif isinstance(item, (bytes, bytearray)):
                stream += item
            else:
                Util.is_type(item, (bytes, bytearray))

        return stream

    def _dict_data(_dict):
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
                Util.is_type(data, (bytes, bytearray))

        return stream

    @staticmethod
    def sign(document, entity, privkeys, keys, exclude=[], multiple=False):
        Util.is_type(document, Document)
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(keys, Keys)

        if not (document.issuer == keys.issuer == entity.id):
            raise RuntimeError(
                'Document/Keys "issuer" or Entity "id" doesn\'t match')

        today = datetime.date.today()

        if today > entity.expires:
            raise RuntimeError('The signing entity has expired')

        if today > keys.expires:
            raise RuntimeError('The verifying keys has expired')

        if not multiple and document.signature:
            raise RuntimeError('Document already signed')

        if multiple and not document._fields['signature'].multiple:
            raise RuntimeError(
                'This document doesn\'t support multiple signatures')

        data = bytes(entity.id.bytes) + Crypto._document_data(
            document, exclude)
        signature = libnacl.sign.Signer(privkeys.seed).signature(data)

        if multiple:
            if not document.signature:
                document.signature = [signature]
            else:
                document.signature.append(signature)
        else:
            document.signature = signature
        document._fields['signature'].redo = False

        return document

    @staticmethod
    def verify(document, entity, keys, exclude=[]):
        Util.is_type(document, Document)
        Util.is_type(entity, Entity)
        Util.is_type(keys, Keys)

        if not (document.issuer == keys.issuer == entity.id):
            raise RuntimeError(
                'Document/Keys issuer or Entity id doesn\'t match')

        data = bytes(document.issuer.bytes) + Crypto._document_data(
            document, exclude)
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
