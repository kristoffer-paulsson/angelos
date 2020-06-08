from unittest import TestCase
from libangelos.library.nacl import SecretBox, Signer, Verifier


class TestSecretBox(TestCase):
    def test_secret_box(self):
        try:
            message = "I love you in Jesus name!".encode()
            box = SecretBox()
            encrypted = box.encrypt(message)
            self.assertNotEqual(message, encrypted)
            decrypted = box.decrypt(encrypted)
            self.assertEqual(message, decrypted)
        except Exception as e:
            self.fail(e)


class TestVerifierSigner(TestCase):
    def test_verifier_signer(self):
        try:
            signer = Signer()
            verifier = Verifier(signer.vk)
            message = "I love you in Jesus name!".encode()
            signed = signer.sign(message)
            self.assertNotEqual(message, signed)
            verified = verifier.verify(signed)
            self.assertEqual(message, verified)
        except Exception as e:
            self.fail(e)
