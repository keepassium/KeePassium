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

#import "YKFFIDO2MakeCredentialAPDU.h"
#import "YKFCBOREncoder.h"
#import "YKFAssert.h"

#import "YKFKeyFIDO2MakeCredentialRequest.h"
#import "YKFKeyFIDO2MakeCredentialRequest+Private.h"

#import "YKFFIDO2Type.h"
#import "YKFFIDO2Type+Private.h"

typedef NS_ENUM(NSUInteger, YKFFIDO2MakeCredentialAPDUKey) {
    YKFFIDO2MakeCredentialAPDUKeyClientDataHash     = 0x01,
    YKFFIDO2MakeCredentialAPDUKeyRp                 = 0x02,
    YKFFIDO2MakeCredentialAPDUKeyUser               = 0x03,
    YKFFIDO2MakeCredentialAPDUKeyPubKeyCredParams   = 0x04,
    YKFFIDO2MakeCredentialAPDUKeyExcludeList        = 0x05,
    YKFFIDO2MakeCredentialAPDUKeyExtensions         = 0x06,
    YKFFIDO2MakeCredentialAPDUKeyOptions            = 0x07,
    YKFFIDO2MakeCredentialAPDUKeyPinAuth            = 0x08,
    YKFFIDO2MakeCredentialAPDUKeyPinProtocol        = 0x09,
};

@implementation YKFFIDO2MakeCredentialAPDU

- (instancetype)initWithRequest:(YKFKeyFIDO2MakeCredentialRequest *)request {
    YKFAssertAbortInit(request)
    YKFAssertAbortInit(request.clientDataHash)
    YKFAssertAbortInit(request.rp)
    YKFAssertAbortInit(request.user)
    YKFAssertAbortInit(request.pubKeyCredParams)
    
    NSMutableDictionary *requestDictionary = [[NSMutableDictionary alloc] init];
    
    // Client Data Hash
    requestDictionary[YKFCBORInteger(YKFFIDO2MakeCredentialAPDUKeyClientDataHash)] = YKFCBORByteString(request.clientDataHash);
    
    // RP
    requestDictionary[YKFCBORInteger(YKFFIDO2MakeCredentialAPDUKeyRp)] = [request.rp cborTypeObject];
    
    // User
    requestDictionary[YKFCBORInteger(YKFFIDO2MakeCredentialAPDUKeyUser)] = [request.user cborTypeObject];
    
    // PubKeyCredParams
    NSMutableArray *pubKeyCredParams = [[NSMutableArray alloc] initWithCapacity:request.pubKeyCredParams.count];
    for (YKFFIDO2PublicKeyCredentialType *credentialType in request.pubKeyCredParams) {
        [pubKeyCredParams addObject:[credentialType cborTypeObject]];
    }
    requestDictionary[YKFCBORInteger(YKFFIDO2MakeCredentialAPDUKeyPubKeyCredParams)] = YKFCBORArray(pubKeyCredParams);
    
    // ExcludeList
    if (request.excludeList) {
        NSMutableArray *excludeList = [[NSMutableArray alloc] initWithCapacity:request.excludeList.count];
        for (YKFFIDO2PublicKeyCredentialDescriptor *descriptor in request.excludeList) {
            [excludeList addObject:[descriptor cborTypeObject]];
        }
        requestDictionary[YKFCBORInteger(YKFFIDO2MakeCredentialAPDUKeyExcludeList)] = YKFCBORArray(excludeList);
    }
    
    // Options
    if (request.options) {
        NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithCapacity:request.options.count];
        NSArray *optionsKeys = request.options.allKeys;
        for (NSString *optionKey in optionsKeys) {
            NSNumber *value = request.options[optionKey];
            options[YKFCBORTextString(optionKey)] = YKFCBORBool(value.boolValue);
        }
        requestDictionary[YKFCBORInteger(YKFFIDO2MakeCredentialAPDUKeyOptions)] = YKFCBORMap(options);
    }
    
    // Pin Auth
    if (request.pinAuth) {
        requestDictionary[YKFCBORInteger(YKFFIDO2MakeCredentialAPDUKeyPinAuth)] = YKFCBORByteString(request.pinAuth);
    }
    
    // Pin Protocol
    if (request.pinProtocol) {
        requestDictionary[YKFCBORInteger(YKFFIDO2MakeCredentialAPDUKeyPinProtocol)] = YKFCBORInteger(request.pinProtocol);
    }

    NSData *cborData = [YKFCBOREncoder encodeMap:YKFCBORMap(requestDictionary)];
    YKFAssertAbortInit(cborData);
    
    return [super initWithCommand:YKFFIDO2CommandMakeCredential data:cborData];
}

@end
