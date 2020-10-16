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

    size_t crypto_aead_xchacha20poly1305_ietf_npubbytes(void)
    size_t crypto_aead_xchacha20poly1305_ietf_keybytes(void)
    size_t crypto_aead_xchacha20poly1305_ietf_abytes(void)
    int crypto_aead_xchacha20poly1305_ietf_encrypt(unsigned char *c, unsigned long long *clen_p, const unsigned char *m, unsigned long long mlen, const unsigned char *ad, unsigned long long adlen, const unsigned char *nsec, const unsigned char *npub, const unsigned char *k)
    int crypto_aead_xchacha20poly1305_ietf_decrypt(unsigned char *m, unsigned long long *mlen_p, unsigned char *nsec, const unsigned char *c, unsigned long long clen, const unsigned char *ad, unsigned long long adlen, const unsigned char *npub, const unsigned char *k)
