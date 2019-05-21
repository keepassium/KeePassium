//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

#include "aeskdf.h"
#include <stdint.h>
#include <CommonCrypto/CommonCrypto.h>


int32_t aeskdf_rounds(const unsigned char *seed, unsigned char *key, const uint64_t nRounds,
                      const aeskdf_progress_fptr progress_callback, const void* user_object) {
    int keySize = kCCKeySizeAES256;
    CCCryptorRef cryptorRef;
    int32_t status = CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128, kCCOptionECBMode, seed, keySize, NULL, &cryptorRef);
    if (status != kCCSuccess) {
        return status;
    }
    
    size_t nMoved;
    for (uint64_t round = 0; round < nRounds; round++) {
        status = CCCryptorUpdate(cryptorRef, key, keySize, key, keySize, &nMoved);
        if (status != kCCSuccess) {
            break;
        }
        if ((round % 100000 == 0) && progress_callback) {
            int should_stop = progress_callback(round, user_object);
            if (should_stop) {
                return kCCSuccess;
            }
        }
    }
    CCCryptorRelease(cryptorRef);
    return status;
}
