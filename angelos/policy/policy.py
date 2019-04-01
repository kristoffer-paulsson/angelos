import base64
import libnacl

from ..utils import Util
# from ..error import Error
from ..document.document import Document
from ..document.entities import Entity, PrivateKeys, Keys


class Policy:
    def _docdata(self, document, exclude=[]):
        stream = bytes()
        exclude += ['issuer', 'signature']
        for field, data in sorted(document.export_bytes().items()):
            if field in exclude:
                continue
            if isinstance(data, list):
                for item in data:
                    stream += item
            else:
                stream += data
        return stream

    def sign(self, document, entity, pk, keys, exclude=[], multiple=False):
        Util.is_type(document, Document)
        Util.is_type(entity, Entity)
        Util.is_type(pk, PrivateKeys)
        Util.is_type(keys, Keys)

        if not (document.issuer == keys.issuer == entity.id):
            raise RuntimeError(
                'Document/Keys "issuer" or Entity "id" doesn\'t match')

        if not multiple and document.signature:
            raise RuntimeError('Document already signed')

        if multiple and not isinstance(document.signature, list):
            raise RuntimeError(
                'This document doesn\'t support multiple signatures')

        data = bytes(entity.id.bytes) + self._docdata(document, exclude)
        signature = str(base64.standard_b64encode(
            libnacl.sign.Signer(
                pk.seed).signature(
                    data)))

        if multiple:
            document.signature.append(signature)
        else:
            document.signature = signature

        return document

    def verify(self, document, entity, keys, exclude=[]):
        Util.is_type(document, Document)
        Util.is_type(entity, Entity)
        Util.is_type(keys, Keys)

        if not (document.issuer == keys.issuer == entity.id):
            raise RuntimeError(
                'Document/Keys issuer or Entity id doesn\'t match')

        data = bytes(document.issuer.bytes) + self._docdata(document, exclude)
        verifier = libnacl.sign.Verifier(keys.verify)

        if isinstance(document.signature, list):
            for signature in document.signature:
                sign = base64.standard_b64decode(signature)
                try:
                    verifier.verify(sign + data)
                    return True
                except ValueError:
                    pass
        else:
            sign = base64.standard_b64decode(document.signature)
            try:
                verifier.verify(sign + data)
                return True
            except ValueError:
                pass
        return False
