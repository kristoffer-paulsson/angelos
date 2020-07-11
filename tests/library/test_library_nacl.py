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
from libangelos.library.nacl import BaseKey, SIZE_SECRETBOX_NONCE, SIZE_SECRETBOX_KEY, SecretBox, SIZE_SECRETBOX_ZERO, \
    SIZE_SECRETBOX_BOXZERO, Signer, SIZE_SIGN, Verifier, PublicKey, SIZE_BOX_PUBLICKEY, SecretKey, SIZE_BOX_SECRETKEY, \
    DualSecret, SIZE_SIGN_PUBLICKEY, SIZE_SIGN_SEED, CryptoBox


class TestBaseKey(TestCase):
    def test_sk(self):
        try:
            key = BaseKey()
            self.assertIs(key.sk, None)
        except Exception as e:
            self.fail(e)

    def test_pk(self):
        try:
            key = BaseKey()
            self.assertIs(key.pk, None)
        except Exception as e:
            self.fail(e)

    def test_vk(self):
        try:
            key = BaseKey()
            self.assertIs(key.vk, None)
        except Exception as e:
            self.fail(e)

    def test_seed(self):
        try:
            key = BaseKey()
            self.assertIs(key.seed, None)
        except Exception as e:
            self.fail(e)

    def test_randombytes(self):
        try:
            rand = BaseKey.randombytes(32)
            self.assertIsInstance(rand, bytes)
            self.assertIs(len(rand), 32)
        except Exception as e:
            self.fail(e)

    def test_rand_nonce(self):
        try:
            nonce = BaseKey.rand_nonce()
            self.assertIsInstance(nonce, bytes)
            self.assertIs(len(nonce), SIZE_SECRETBOX_NONCE)
        except Exception as e:
            self.fail(e)

    def test__salsa_key(self):
        try:
            key = BaseKey()
            salsa = key._salsa_key()
            self.assertIsInstance(salsa, bytes)
            self.assertIs(len(salsa), SIZE_SECRETBOX_KEY)
        except Exception as e:
            self.fail(e)


class TestSecretBox(TestCase):
    def test_encrypt(self):
        try:
            message = "I love you in Jesus name!".encode()
            box = SecretBox()
            encrypted = box.encrypt(message)
            self.assertNotEqual(message, encrypted)
            self.assertIs(
                len(encrypted),
                len(message) + SIZE_SECRETBOX_ZERO + SIZE_SECRETBOX_NONCE - SIZE_SECRETBOX_BOXZERO
            )
        except Exception as e:
            self.fail(e)

    def test_decrypt(self):
        try:
            message = "I love you in Jesus name!".encode()
            box = SecretBox()
            encrypted = box.encrypt(message)
            self.assertNotEqual(message, encrypted)
            decrypted = box.decrypt(encrypted)
            self.assertEqual(message, decrypted)
        except Exception as e:
            self.fail(e)


class TestSigner(TestCase):
    def test_sign(self):
        try:
            signer = Signer()
            message = "I love you in Jesus name!".encode()
            signed = signer.sign(message)
            self.assertIn(message, signed)
            self.assertIs(len(signed), len(message) + SIZE_SIGN)
            self.assertEqual(Verifier(signer.vk).verify(signed), message)
        except Exception as e:
            self.fail(e)

    def test_signature(self):
        try:
            signer = Signer()
            message = "I love you in Jesus name!".encode()
            signature = signer.signature(message)
            self.assertNotIn(message, signature)
            self.assertIs(len(signature), SIZE_SIGN)
            self.assertEqual(Verifier(signer.vk).verify(signature + message), message)
        except Exception as e:
            self.fail(e)


class TestVerifier(TestCase):
    def test_verify(self):
        try:
            signer = Signer()
            verifier = Verifier(signer.vk)
            message = "I love you in Jesus name!".encode()
            self.assertEqual(verifier.verify(signer.sign(message)), message)
            self.assertEqual(verifier.verify(signer.signature(message) + message), message)
            with self.assertRaises(ValueError):
                verifier.verify(message)
        except Exception as e:
            self.fail(e)


class TestPublicKey(TestCase):
    def test_pk(self):
        try:
            key = PublicKey(BaseKey.randombytes(SIZE_BOX_PUBLICKEY))
            self.assertIsInstance(key.pk, bytes)
            self.assertIs(len(key.pk), SIZE_BOX_PUBLICKEY)
            with self.assertRaises(ValueError):
                PublicKey(BaseKey.randombytes(SIZE_BOX_PUBLICKEY - 1))
        except Exception as e:
            self.fail(e)


class TestSecretKey(TestCase):
    def test_sk(self):
        try:
            key = SecretKey(BaseKey.randombytes(SIZE_BOX_SECRETKEY))
            self.assertIsInstance(key.sk, bytes)
            self.assertIs(len(key.sk), SIZE_BOX_SECRETKEY)

            key = SecretKey()
            self.assertIsInstance(key.sk, bytes)
            self.assertIs(len(key.sk), SIZE_BOX_SECRETKEY)

            with self.assertRaises(ValueError):
                SecretKey(BaseKey.randombytes(SIZE_BOX_SECRETKEY - 1))
        except Exception as e:
            self.fail(e)

    def test_pk(self):
        try:
            key = SecretKey(BaseKey.randombytes(SIZE_BOX_SECRETKEY))
            self.assertIsInstance(key.pk, bytes)
            self.assertIs(len(key.pk), SIZE_BOX_PUBLICKEY)

            key = SecretKey()
            self.assertIsInstance(key.pk, bytes)
            self.assertIs(len(key.pk), SIZE_BOX_PUBLICKEY)

            with self.assertRaises(ValueError):
                SecretKey(BaseKey.randombytes(SIZE_BOX_SECRETKEY - 1))
        except Exception as e:
            self.fail(e)


class TestDualSecret(TestCase):
    def test_sign(self):
        try:
            dual = DualSecret()
            message = "I love you in Jesus name!".encode()
            signed = dual.sign(message)
            self.assertIn(message, signed)
            self.assertIs(len(signed), len(message) + SIZE_SIGN)
            self.assertEqual(Verifier(dual.vk).verify(signed), message)
        except Exception as e:
            self.fail(e)

    def test_signature(self):
        try:
            dual = DualSecret()
            message = "I love you in Jesus name!".encode()
            signature = dual.signature(message)
            self.assertNotIn(message, signature)
            self.assertIs(len(signature), SIZE_SIGN)
            self.assertEqual(Verifier(dual.vk).verify(signature + message), message)
        except Exception as e:
            self.fail(e)

    def test_sk(self):
        try:
            dual = DualSecret()
            self.assertIsInstance(dual.sk, bytes)
            self.assertIs(len(dual.sk), SIZE_BOX_SECRETKEY)
        except Exception as e:
            self.fail(e)

    def test_pk(self):
        try:
            dual = DualSecret()
            self.assertIsInstance(dual.pk, bytes)
            self.assertIs(len(dual.pk), SIZE_BOX_PUBLICKEY)
        except Exception as e:
            self.fail(e)

    def test_vk(self):
        try:
            dual = DualSecret()
            self.assertIsInstance(dual.vk, bytes)
            self.assertIs(len(dual.vk), SIZE_SIGN_PUBLICKEY)
        except Exception as e:
            self.fail(e)

    def test_seed(self):
        try:
            dual = DualSecret()
            self.assertIsInstance(dual.seed, bytes)
            self.assertIs(len(dual.seed), SIZE_SIGN_SEED)
        except Exception as e:
            self.fail(e)


class TestCryptoBox(TestCase):
    def test_encrypt(self):
        try:
            message = "I love you in Jesus name!".encode()
            bengt = SecretKey()
            evert = SecretKey()
            bengt_box = CryptoBox(bengt, PublicKey(evert.pk))
            evert_box = CryptoBox(evert, PublicKey(bengt.pk))

            encrypted = bengt_box.encrypt(message)
            self.assertNotEqual(message, encrypted)
            self.assertIs(
                len(encrypted),
                len(message) + SIZE_SECRETBOX_ZERO + SIZE_SECRETBOX_NONCE - SIZE_SECRETBOX_BOXZERO
            )
        except Exception as e:
            self.fail(e)

    def test_decrypt(self):
        try:
            message = "I love you in Jesus name!".encode()
            bengt = SecretKey()
            evert = SecretKey()
            bengt_box = CryptoBox(bengt, PublicKey(evert.pk))
            evert_box = CryptoBox(evert, PublicKey(bengt.pk))

            encrypted = bengt_box.encrypt(message)

            self.assertNotEqual(message, encrypted)
            decrypted = evert_box.decrypt(encrypted)
            self.assertEqual(message, decrypted)
        except Exception as e:
            self.fail(e)
