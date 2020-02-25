// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import "YKFCBORType.h"

NS_ASSUME_NONNULL_BEGIN

@interface YKFFIDO2PinAuthKey: NSObject

@property (nonatomic, readonly, nullable) SecKeyRef publicKey;
@property (nonatomic, readonly, nullable) SecKeyRef privateKey;

/// Returns the COSE representation for the public key (ECC only).
@property (nonatomic, readonly, nullable) YKFCBORMap *cosePublicKey;

/// Generates an ECC key pair.
- (nullable instancetype)init;

/// Initializes the publicKey from a COSE public key representation (ECC only).
- (nullable instancetype)initWithCosePublicKey:(NSDictionary *)cosePublicKey;

/// Returns an ECDH shared secret: ECDH(self.privateKey, otherKey.publicKey).
- (nullable NSData *)sharedSecretWithAuthKey:(YKFFIDO2PinAuthKey *)otherKey;

@end

NS_ASSUME_NONNULL_END
