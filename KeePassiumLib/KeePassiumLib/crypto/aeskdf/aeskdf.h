//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

#ifndef aeskdf_h
#define aeskdf_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

    

/// [AP] type for Swift progress callback
/// @param  round  transformation rounds done so far
/// @param  swift_obj  any Swift object passed to aeskdf_rounds()
/// @return zero to continue transformation, anyhing else to stop
typedef int (*aeskdf_progress_fptr)(uint64_t round, const void *swift_obj);

/// Native implementation of AES KDF rounds, for higher performance.
/// Performs `nRounds` of AES KDF rounds on the `key`, starting from `seed`.
/// Periodically calls `progress_callback` with `user_object` as a parameter.
int32_t aeskdf_rounds(const unsigned char *seed, unsigned char *key, const uint64_t nRounds,
                      const aeskdf_progress_fptr progress_callback, const void* user_object);

#ifdef __cplusplus
}
#endif

#endif /* aeskdf_h */
