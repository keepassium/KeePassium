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

#import <CommonCrypto/CommonCrypto.h>
#import "YKFOATHCredentialValidator.h"
#import "YKFKeyOATHError.h"
#import "YKFAssert.h"

#import "YKFKeySessionError+Private.h"
#import "YKFOATHCredential+Private.h"

static const int YKFOATHCredentialValidatorMaxNameSize = 64;

@implementation YKFOATHCredentialValidator

+ (YKFKeySessionError *)validateCredential:(YKFOATHCredential *)credential includeSecret:(BOOL)secretIncluded {
    YKFParameterAssertReturnValue(credential, nil);
    
    if (credential.key.length > YKFOATHCredentialValidatorMaxNameSize) {
        return [YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeNameTooLong];
    }
    if (secretIncluded) {
        NSData *credentialSecret = credential.secret;
        int shaAlgorithmBlockSize = 0;
        switch (credential.algorithm) {
            case YKFOATHCredentialAlgorithmSHA1:
                shaAlgorithmBlockSize = CC_SHA1_BLOCK_BYTES;
                break;
            case YKFOATHCredentialAlgorithmSHA256:
                shaAlgorithmBlockSize = CC_SHA256_BLOCK_BYTES;
                break;
            case YKFOATHCredentialAlgorithmSHA512:
                shaAlgorithmBlockSize = CC_SHA512_BLOCK_BYTES;
                break;
            default:
                YKFAssertReturnValue(NO, @"Invalid OATH algorithm.", nil);
        }
        if (credentialSecret.length > shaAlgorithmBlockSize) {
            return [YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeSecretTooLong];
        }
    }
    return nil;
}

@end
