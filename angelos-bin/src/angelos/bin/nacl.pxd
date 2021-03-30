# cython: language_level=3
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

cdef extern from "sodium.h":
    # Internals
    int sodium_init()
    # Crypto
    void randombytes(unsigned char *buf, const unsigned long long buf_len)
    size_t crypto_box_noncebytes()
    int crypto_secretbox(
            unsigned char *c, const unsigned char *m, unsigned long long mlen, const unsigned char *n,
            const unsigned char *k)
    int crypto_secretbox_open(
            unsigned char *m, const unsigned char *c, unsigned long long clen, const unsigned char *n,
            const unsigned char *k)
    size_t crypto_secretbox_noncebytes()
    size_t crypto_secretbox_keybytes()
    size_t crypto_secretbox_zerobytes()
    size_t crypto_secretbox_boxzerobytes()
    size_t crypto_sign_secretkeybytes()
    size_t crypto_sign_bytes()
    size_t crypto_sign_secretkeybytes()
    size_t crypto_sign_publickeybytes()
    int crypto_sign_seed_keypair(unsigned char *pk, unsigned char *sk, const unsigned char *seed)
    int crypto_sign(unsigned char *sm, unsigned long long *smlen_p, const unsigned char *m, unsigned long long mlen,
                    const unsigned char *sk)
    int crypto_sign_open(unsigned char *m, unsigned long long *mlen_p, const unsigned char *sm,
                         unsigned long long smlen, const unsigned char *pk)
    size_t crypto_box_publickeybytes()
    size_t crypto_box_secretkeybytes()
    int crypto_box_keypair(unsigned char *pk, unsigned char *sk)
    int crypto_scalarmult_base(unsigned char *q, const unsigned char *n)
    size_t crypto_box_beforenmbytes()
    int crypto_box_beforenm(unsigned char *k, const unsigned char *pk, const unsigned char *sk)
    size_t crypto_box_zerobytes()
    int crypto_box_afternm(unsigned char *c, const unsigned char *m, unsigned long long mlen, const unsigned char *n, const unsigned char *k)
    size_t crypto_box_boxzerobytes()
    int crypto_box_open_afternm(unsigned char *m, const unsigned char *c, unsigned long long clen, const unsigned char *n, const unsigned char *k)

    # Client/server key-exchange
    size_t crypto_kx_publickeybytes()
    size_t crypto_kx_secretkeybytes()
    size_t crypto_kx_sessionkeybytes()

    int crypto_kx_keypair(unsigned char *pk, unsigned char *sk)
    int crypto_kx_client_session_keys(unsigned char *rx, unsigned char *tx, const unsigned char *client_pk, const unsigned char *client_sk, const unsigned char *server_pk)
    int crypto_kx_server_session_keys(unsigned char *rx, unsigned char *tx, const unsigned char *server_pk, const unsigned char *server_sk, const unsigned char *client_pk)

    size_t crypto_aead_xchacha20poly1305_ietf_npubbytes()
    size_t crypto_aead_xchacha20poly1305_ietf_keybytes()
    size_t crypto_aead_xchacha20poly1305_ietf_abytes()
    int crypto_aead_xchacha20poly1305_ietf_encrypt(unsigned char *c, unsigned long long *clen_p, const unsigned char *m, unsigned long long mlen, const unsigned char *ad, unsigned long long adlen, const unsigned char *nsec, const unsigned char *npub, const unsigned char *k)
    int crypto_aead_xchacha20poly1305_ietf_decrypt(unsigned char *m, unsigned long long *mlen_p, unsigned char *nsec, const unsigned char *c, unsigned long long clen, const unsigned char *ad, unsigned long long adlen, const unsigned char *npub, const unsigned char *k)

    # Generic hash
    size_t crypto_generichash_bytes()
    size_t crypto_generichash_bytes_min()
    size_t crypto_generichash_bytes_max()
    size_t crypto_generichash_keybytes()

    cdef int crypto_generichash_KEYBYTES
    void crypto_generichash_keygen(unsigned char k[64])
    int crypto_generichash(unsigned char *out, size_t outlen, const unsigned char *inp, unsigned long long inplen, const unsigned char *key, size_t keylen)

    # Base64
    cdef int sodium_base64_VARIANT_URLSAFE = 5
    char *sodium_bin2base64(const char * b64, const size_t b64_maxlen, const unsigned char * bin, const size_t bin_len, const int variant)
    int sodium_base642bin(const unsigned char * bin, const size_t bin_maxlen, const char * b64, const size_t b64_len, const char * ignore, const size_t * bin_len, const char ** b64_end, const int variant)
    size_t sodium_base64_encoded_len(const size_t bin_len, const int variant)

    # Curve25519
    void randombytes_buf(void * buf, const size_t size)
    int crypto_scalarmult(unsigned char *q, const unsigned char *n, const unsigned char *p)
    size_t  crypto_scalarmult_scalarbytes()
    size_t  crypto_scalarmult_bytes()

    # ChaChaPoly
    int crypto_aead_chacha20poly1305_encrypt(unsigned char *c, unsigned long long *clen_p, const unsigned char *m, unsigned long long mlen, const unsigned char *ad, unsigned long long adlen, const unsigned char *nsec, const unsigned char *npub, const unsigned char *k)
    int crypto_aead_chacha20poly1305_decrypt(unsigned char *m, unsigned long long *mlen_p, unsigned char *nsec, const unsigned char *c, unsigned long long clen, const unsigned char *ad, unsigned long long adlen, const unsigned char *npub, const unsigned char *k)
    size_t crypto_aead_chacha20poly1305_keybytes()
    size_t crypto_aead_chacha20poly1305_npubbytes()
    size_t crypto_aead_chacha20poly1305_abytes()