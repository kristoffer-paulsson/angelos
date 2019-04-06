import libnacl
import datetime

from ..utils import Util
from ..document.document import Document
from ..document.entities import Entity, PrivateKeys, Keys


class Crypto:
    @staticmethod
    def _docdata(document, exclude=[]):
        stream = bytes()
        exclude += ['issuer', 'signature']
        for field, data in sorted(document.export_bytes().items()):
            if field in exclude:
                continue
            elif isinstance(data, list):
                for item in data:
                    stream += item
            elif isinstance(data, dict):
                for item in data.keys():
                    stream += data[item]
            else:
                stream += data
        return stream

    @staticmethod
    def sign(document, entity, pk, keys, exclude=[], multiple=False):
        Util.is_type(document, Document)
        Util.is_type(entity, Entity)
        Util.is_type(pk, PrivateKeys)
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

        data = bytes(entity.id.bytes) + Crypto._docdata(
            document, exclude)
        signature = libnacl.sign.Signer(pk.seed).signature(data)

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

        data = bytes(document.issuer.bytes) + Crypto._docdata(
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
