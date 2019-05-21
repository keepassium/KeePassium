//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

#ifndef salsa20_h
#define salsa20_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/**
 * Salsa 20 implementation adopted from the reference
 * implementation by D. J. Bernstein (version 20080912).
 * Taken from http://code.metager.de/source/xref/lib/nacl/20110221/crypto_core/salsa20/ref/core.c
 * Public domain.
 */
//int salsa20_core(unsigned char *out, const unsigned char *in, const unsigned char *k, const unsigned char *c);
int salsa20_core(unsigned char *out, const unsigned char *iv, const unsigned char *counter, const unsigned char *k, const unsigned char *c);

#ifdef __cplusplus
}
#endif

#endif /* salsa20_h */
