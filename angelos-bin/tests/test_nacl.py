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
from unittest import TestCase
from angelos.bin.nacl import BaseKey, SIZE_SECRETBOX_NONCE, SIZE_SECRETBOX_KEY, SecretBox, SIZE_SECRETBOX_ZERO, \
    SIZE_SECRETBOX_BOXZERO, Signer, SIZE_SIGN, Verifier, PublicKey, SIZE_BOX_PUBLICKEY, SecretKey, SIZE_BOX_SECRETKEY, \
    DualSecret, SIZE_SIGN_PUBLICKEY, SIZE_SIGN_SEED, CryptoBox, NaCl, SIZE_AEAD_NPUB, NaClError, CryptoFailure

MESSAGE = "I love you in Jesus name!".encode()


class TestNaCl(TestCase):
    def test_random_bytes(self):
        rand = NaCl.random_bytes(32)
        self.assertIsInstance(rand, bytes)
        self.assertIs(len(rand), 32)

    def test_random_nonce(self):
        nonce = NaCl.random_nonce()
        self.assertIsInstance(nonce, bytes)
        self.assertIs(len(nonce), SIZE_SECRETBOX_NONCE)

    def test_random_aead_nonce(self):
        nonce = NaCl.random_aead_nonce()
        self.assertIsInstance(nonce, bytes)
        self.assertIs(len(nonce), SIZE_AEAD_NPUB)

    def test_salsa_key(self):
        salsa = NaCl.salsa_key()
        self.assertIsInstance(salsa, bytes)
        self.assertIs(len(salsa), SIZE_SECRETBOX_KEY)


class TestBaseKey(TestCase):
    def test_sk(self):
        key = BaseKey()
        self.assertIs(key.sk, None)

    def test_pk(self):
        key = BaseKey()
        self.assertIs(key.pk, None)

    def test_vk(self):
        key = BaseKey()
        self.assertIs(key.vk, None)

    def test_seed(self):
        key = BaseKey()
        self.assertIs(key.seed, None)


class TestSecretBox(TestCase):
    def test_encrypt(self):
        box = SecretBox()
        encrypted = box.encrypt(MESSAGE)
        self.assertNotEqual(MESSAGE, encrypted)
        self.assertIs(
            len(encrypted),
            len(MESSAGE) + SIZE_SECRETBOX_ZERO + SIZE_SECRETBOX_NONCE - SIZE_SECRETBOX_BOXZERO
        )

    def test_decrypt(self):
        box = SecretBox()
        encrypted = box.encrypt(MESSAGE)
        self.assertNotEqual(MESSAGE, encrypted)
        decrypted = box.decrypt(encrypted)
        self.assertEqual(MESSAGE, decrypted)


class TestSigner(TestCase):
    def test_sign(self):
        signer = Signer()
        signed = signer.sign(MESSAGE)
        self.assertIn(MESSAGE, signed)
        self.assertIs(len(signed), len(MESSAGE) + SIZE_SIGN)
        self.assertEqual(Verifier(signer.vk).verify(signed), MESSAGE)

    def test_signature(self):
        signer = Signer()
        signature = signer.signature(MESSAGE)
        self.assertNotIn(MESSAGE, signature)
        self.assertIs(len(signature), SIZE_SIGN)
        self.assertEqual(Verifier(signer.vk).verify(signature + MESSAGE), MESSAGE)


class TestVerifier(TestCase):
    def test_verify(self):
        signer = Signer()
        verifier = Verifier(signer.vk)
        self.assertEqual(verifier.verify(signer.sign(MESSAGE)), MESSAGE)
        self.assertEqual(verifier.verify(signer.signature(MESSAGE) + MESSAGE), MESSAGE)
        with self.assertRaises(CryptoFailure):
            verifier.verify(MESSAGE)


class TestPublicKey(TestCase):
    def test_pk(self):
        key = PublicKey(NaCl.random_bytes(SIZE_BOX_PUBLICKEY))
        self.assertIsInstance(key.pk, bytes)
        self.assertIs(len(key.pk), SIZE_BOX_PUBLICKEY)
        with self.assertRaises(NaClError):
            PublicKey(NaCl.random_bytes(SIZE_BOX_PUBLICKEY - 1))


class TestSecretKey(TestCase):
    def test_sk(self):
        key = SecretKey(NaCl.random_bytes(SIZE_BOX_SECRETKEY))
        self.assertIsInstance(key.sk, bytes)
        self.assertIs(len(key.sk), SIZE_BOX_SECRETKEY)

        key = SecretKey()
        self.assertIsInstance(key.sk, bytes)
        self.assertIs(len(key.sk), SIZE_BOX_SECRETKEY)

        with self.assertRaises(NaClError):
            SecretKey(NaCl.random_bytes(SIZE_BOX_SECRETKEY - 1))

    def test_pk(self):
        key = SecretKey(NaCl.random_bytes(SIZE_BOX_SECRETKEY))
        self.assertIsInstance(key.pk, bytes)
        self.assertIs(len(key.pk), SIZE_BOX_PUBLICKEY)

        key = SecretKey()
        self.assertIsInstance(key.pk, bytes)
        self.assertIs(len(key.pk), SIZE_BOX_PUBLICKEY)

        with self.assertRaises(NaClError):
            SecretKey(NaCl.random_bytes(SIZE_BOX_SECRETKEY - 1))


class TestDualSecret(TestCase):
    def test_sign(self):
        dual = DualSecret()
        signed = dual.sign(MESSAGE)
        self.assertIn(MESSAGE, signed)
        self.assertIs(len(signed), len(MESSAGE) + SIZE_SIGN)
        self.assertEqual(Verifier(dual.vk).verify(signed), MESSAGE)

    def test_signature(self):
        dual = DualSecret()
        signature = dual.signature(MESSAGE)
        self.assertNotIn(MESSAGE, signature)
        self.assertIs(len(signature), SIZE_SIGN)
        self.assertEqual(Verifier(dual.vk).verify(signature + MESSAGE), MESSAGE)

    def test_sk(self):
        dual = DualSecret()
        self.assertIsInstance(dual.sk, bytes)
        self.assertIs(len(dual.sk), SIZE_BOX_SECRETKEY)

    def test_pk(self):
        dual = DualSecret()
        self.assertIsInstance(dual.pk, bytes)
        self.assertIs(len(dual.pk), SIZE_BOX_PUBLICKEY)

    def test_vk(self):
        dual = DualSecret()
        self.assertIsInstance(dual.vk, bytes)
        self.assertIs(len(dual.vk), SIZE_SIGN_PUBLICKEY)

    def test_seed(self):
        dual = DualSecret()
        self.assertIsInstance(dual.seed, bytes)
        self.assertIs(len(dual.seed), SIZE_SIGN_SEED)


class TestCryptoBox(TestCase):
    def test_encrypt(self):
        bengt = SecretKey()
        evert = SecretKey()
        bengt_box = CryptoBox(bengt, PublicKey(evert.pk))

        encrypted = bengt_box.encrypt(MESSAGE)
        self.assertNotEqual(MESSAGE, encrypted)
        self.assertIs(
            len(encrypted),
            len(MESSAGE) + SIZE_SECRETBOX_ZERO + SIZE_SECRETBOX_NONCE - SIZE_SECRETBOX_BOXZERO
        )

    def test_decrypt(self):
        bengt = SecretKey()
        evert = SecretKey()
        bengt_box = CryptoBox(bengt, PublicKey(evert.pk))
        evert_box = CryptoBox(evert, PublicKey(bengt.pk))

        encrypted = bengt_box.encrypt(MESSAGE)

        self.assertNotEqual(MESSAGE, encrypted)
        decrypted = evert_box.decrypt(encrypted)
        self.assertEqual(MESSAGE, decrypted)



