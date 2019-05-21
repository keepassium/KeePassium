/*
 Adapted from the reference implementation:
 
 chacha-merged.c version 20080118
 D. J. Bernstein
 http://cr.yp.to/streamciphers/timings/estreambench/submissions/salsa20/chacha20/merged/chacha.c
 Public domain.
 */

#include <stdint.h>
#include <string.h> // for memcpy()

static inline uint32_t chacha20_rotl32(const uint32_t x, const int b) {
    return (x << b) | (x >> (32 - b));
}

static inline uint32_t chacha20_load32_le(const uint8_t src[4]) {
//    // iOS is natively little endian
//    uint32_t w;
//    memcpy(&w, src, sizeof w);
//    return w;

    // Generic code for arbitrary platform
    uint32_t w = (uint32_t) src[0];
    w |= (uint32_t) src[1] <<  8;
    w |= (uint32_t) src[2] << 16;
    w |= (uint32_t) src[3] << 24;
    return w;
}

static inline void chacha20_store32_le(uint8_t dst[4], uint32_t w) {
//    // iOS is natively little endian
//    memcpy(dst, &w, sizeof w);
    
    // Generic code for arbitrary platform
    dst[0] = (uint8_t) w; w >>= 8;
    dst[1] = (uint8_t) w; w >>= 8;
    dst[2] = (uint8_t) w; w >>= 8;
    dst[3] = (uint8_t) w;
}

#define CHACHA20_QUARTERROUND(a, b, c, d) \
a += b; d = chacha20_rotl32(d ^ a, 16);   \
c += d; b = chacha20_rotl32(b ^ c, 12);   \
a += b; d = chacha20_rotl32(d ^ a, 8);    \
c += d; b = chacha20_rotl32(b ^ c, 7);



/// Generates a 64-byte block of ChaCha20 stream
/// - Parameter: key - 32 bytes
/// - Parameter: iv - 12 bytes
/// - Parameter: counter - UInt32
/// - Parameter: output - preallocated 64-byte output array
void chacha20_make_block(const uint8_t *key, const uint8_t *iv,
                                const uint8_t *counter, uint8_t *output) {
    uint32_t x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15;
    uint32_t j0, j1, j2, j3, j4, j5, j6, j7, j8, j9, j10, j11, j12, j13, j14, j15;
    
    x0  = j0  = 0x61707865;
    x1  = j1  = 0x3320646e;
    x2  = j2  = 0x79622d32;
    x3  = j3  = 0x6b206574;
    x4  = j4  = chacha20_load32_le(key + 0);
    x5  = j5  = chacha20_load32_le(key + 4);
    x6  = j6  = chacha20_load32_le(key + 8);
    x7  = j7  = chacha20_load32_le(key + 12);
    x8  = j8  = chacha20_load32_le(key + 16);
    x9  = j9  = chacha20_load32_le(key + 20);
    x10 = j10 = chacha20_load32_le(key + 24);
    x11 = j11 = chacha20_load32_le(key + 28);
    x12 = j12 = chacha20_load32_le(counter + 0); // IETF setup with 32-bit counter
    x13 = j13 = chacha20_load32_le(iv + 0);
    x14 = j14 = chacha20_load32_le(iv + 4);
    x15 = j15 = chacha20_load32_le(iv + 8);
    
    
    for (int i = 20; i > 0; i -= 2) {
        CHACHA20_QUARTERROUND(x0, x4, x8, x12)
        CHACHA20_QUARTERROUND(x1, x5, x9, x13)
        CHACHA20_QUARTERROUND(x2, x6, x10, x14)
        CHACHA20_QUARTERROUND(x3, x7, x11, x15)
        CHACHA20_QUARTERROUND(x0, x5, x10, x15)
        CHACHA20_QUARTERROUND(x1, x6, x11, x12)
        CHACHA20_QUARTERROUND(x2, x7, x8, x13)
        CHACHA20_QUARTERROUND(x3, x4, x9, x14)
    }
    x0  += j0;
    x1  += j1;
    x2  += j2;
    x3  += j3;
    x4  += j4;
    x5  += j5;
    x6  += j6;
    x7  += j7;
    x8  += j8;
    x9  += j9;
    x10 += j10;
    x11 += j11;
    x12 += j12;
    x13 += j13;
    x14 += j14;
    x15 += j15;
    
    chacha20_store32_le(output + 0, x0);
    chacha20_store32_le(output + 4, x1);
    chacha20_store32_le(output + 8, x2);
    chacha20_store32_le(output + 12, x3);
    chacha20_store32_le(output + 16, x4);
    chacha20_store32_le(output + 20, x5);
    chacha20_store32_le(output + 24, x6);
    chacha20_store32_le(output + 28, x7);
    chacha20_store32_le(output + 32, x8);
    chacha20_store32_le(output + 36, x9);
    chacha20_store32_le(output + 40, x10);
    chacha20_store32_le(output + 44, x11);
    chacha20_store32_le(output + 48, x12);
    chacha20_store32_le(output + 52, x13);
    chacha20_store32_le(output + 56, x14);
    chacha20_store32_le(output + 60, x15);
}
