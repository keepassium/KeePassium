/**
 * Salsa20 implementation adapted from the reference implementation by D. J. Bernstein (version 20080912).
 * Taken from http://code.metager.de/source/xref/lib/nacl/20110221/crypto_core/salsa20/ref/core.c
 * Public domain.
 */

#include "salsa20.h"
#include <stdint.h>
#include <stdio.h>

uint32_t salsa20_rotate(uint32_t u, int c) {
  return (u << c) | (u >> (32 - c));
}

uint32_t salsa20_load_littleendian(const unsigned char *x) {
  return (uint32_t) (x[0]) \
      | (((uint32_t) (x[1])) << 8) \
      | (((uint32_t) (x[2])) << 16) \
      | (((uint32_t) (x[3])) << 24);
}

static void salsa20_store_littleendian(unsigned char *x, uint32_t u) {
  x[0] = u; u >>= 8;
  x[1] = u; u >>= 8;
  x[2] = u; u >>= 8;
  x[3] = u;
}

//int salsa20_core(unsigned char *out, const unsigned char *in, const unsigned char *k, const unsigned char *c) {
int salsa20_core(unsigned char *out, const unsigned char *iv, const unsigned char *counter, const unsigned char *k, const unsigned char *c) {
    uint32_t x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15;
    uint32_t j0, j1, j2, j3, j4, j5, j6, j7, j8, j9, j10, j11, j12, j13, j14, j15;
    int i;

    const int ROUNDS = 20;

    j0 = x0 = salsa20_load_littleendian(c + 0);
    j1 = x1 = salsa20_load_littleendian(k + 0);
    j2 = x2 = salsa20_load_littleendian(k + 4);
    j3 = x3 = salsa20_load_littleendian(k + 8);
    j4 = x4 = salsa20_load_littleendian(k + 12);
    j5 = x5 = salsa20_load_littleendian(c + 4);
    j6 = x6 = salsa20_load_littleendian(iv + 0);
    j7 = x7 = salsa20_load_littleendian(iv + 4);
    j8 = x8 = salsa20_load_littleendian(counter + 0);
    j9 = x9 = salsa20_load_littleendian(counter + 4);
    j10 = x10 = salsa20_load_littleendian(c + 8);
    j11 = x11 = salsa20_load_littleendian(k + 16);
    j12 = x12 = salsa20_load_littleendian(k + 20);
    j13 = x13 = salsa20_load_littleendian(k + 24);
    j14 = x14 = salsa20_load_littleendian(k + 28);
    j15 = x15 = salsa20_load_littleendian(c + 12);

    for (i = ROUNDS;i > 0;i -= 2) {
         x4 ^= salsa20_rotate( x0+x12, 7);
         x8 ^= salsa20_rotate( x4+ x0, 9);
        x12 ^= salsa20_rotate( x8+ x4,13);
         x0 ^= salsa20_rotate(x12+ x8,18);
         x9 ^= salsa20_rotate( x5+ x1, 7);
        x13 ^= salsa20_rotate( x9+ x5, 9);
         x1 ^= salsa20_rotate(x13+ x9,13);
         x5 ^= salsa20_rotate( x1+x13,18);
        x14 ^= salsa20_rotate(x10+ x6, 7);
         x2 ^= salsa20_rotate(x14+x10, 9);
         x6 ^= salsa20_rotate( x2+x14,13);
        x10 ^= salsa20_rotate( x6+ x2,18);
         x3 ^= salsa20_rotate(x15+x11, 7);
         x7 ^= salsa20_rotate( x3+x15, 9);
        x11 ^= salsa20_rotate( x7+ x3,13);
        x15 ^= salsa20_rotate(x11+ x7,18);
         x1 ^= salsa20_rotate( x0+ x3, 7);
         x2 ^= salsa20_rotate( x1+ x0, 9);
         x3 ^= salsa20_rotate( x2+ x1,13);
         x0 ^= salsa20_rotate( x3+ x2,18);
         x6 ^= salsa20_rotate( x5+ x4, 7);
         x7 ^= salsa20_rotate( x6+ x5, 9);
         x4 ^= salsa20_rotate( x7+ x6,13);
         x5 ^= salsa20_rotate( x4+ x7,18);
        x11 ^= salsa20_rotate(x10+ x9, 7);
         x8 ^= salsa20_rotate(x11+x10, 9);
         x9 ^= salsa20_rotate( x8+x11,13);
        x10 ^= salsa20_rotate( x9+ x8,18);
        x12 ^= salsa20_rotate(x15+x14, 7);
        x13 ^= salsa20_rotate(x12+x15, 9);
        x14 ^= salsa20_rotate(x13+x12,13);
        x15 ^= salsa20_rotate(x14+x13,18);
    }

    x0 += j0;
    x1 += j1;
    x2 += j2;
    x3 += j3;
    x4 += j4;
    x5 += j5;
    x6 += j6;
    x7 += j7;
    x8 += j8;
    x9 += j9;
    x10 += j10;
    x11 += j11;
    x12 += j12;
    x13 += j13;
    x14 += j14;
    x15 += j15;

    salsa20_store_littleendian(out + 0,x0);
    salsa20_store_littleendian(out + 4,x1);
    salsa20_store_littleendian(out + 8,x2);
    salsa20_store_littleendian(out + 12,x3);
    salsa20_store_littleendian(out + 16,x4);
    salsa20_store_littleendian(out + 20,x5);
    salsa20_store_littleendian(out + 24,x6);
    salsa20_store_littleendian(out + 28,x7);
    salsa20_store_littleendian(out + 32,x8);
    salsa20_store_littleendian(out + 36,x9);
    salsa20_store_littleendian(out + 40,x10);
    salsa20_store_littleendian(out + 44,x11);
    salsa20_store_littleendian(out + 48,x12);
    salsa20_store_littleendian(out + 52,x13);
    salsa20_store_littleendian(out + 56,x14);
    salsa20_store_littleendian(out + 60,x15);

    return 0;
}
