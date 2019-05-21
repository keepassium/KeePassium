//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

#ifndef chacha20_h
#define chacha20_h

#ifdef __cplusplus
extern "C" {
#endif
    
#include <stdint.h>

void chacha20_make_block(const uint8_t *key, const uint8_t *iv, const uint8_t *counter, uint8_t *output);
    
#ifdef __cplusplus
}
#endif

#endif /* chacha20_h */
