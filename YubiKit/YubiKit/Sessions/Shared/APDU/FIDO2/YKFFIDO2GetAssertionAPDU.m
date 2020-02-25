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

#import "YKFFIDO2GetAssertionAPDU.h"
#import "YKFCBORType.h"
#import "YKFCBOREncoder.h"
#import "YKFAssert.h"

#import "YKFKeyFIDO2GetAssertionRequest.h"
#import "YKFKeyFIDO2GetAssertionRequest+Private.h"

#import "YKFFIDO2Type.h"
#import "YKFFIDO2Type+Private.h"

typedef NS_ENUM(NSUInteger, YKFFIDO2GetAssertionAPDUKey) {
    YKFFIDO2GetAssertionAPDUKeyRp               = 0x01,
    YKFFIDO2GetAssertionAPDUKeyClientDataHash   = 0x02,
    YKFFIDO2GetAssertionAPDUKeyAllowList        = 0x03,
    YKFFIDO2GetAssertionAPDUKeyExtensions       = 0x04,
    YKFFIDO2GetAssertionAPDUKeyOptions          = 0x05,
    YKFFIDO2GetAssertionAPDUKeyPinAuth          = 0x06,
    YKFFIDO2GetAssertionAPDUKeyPinProtocol      = 0x07
};

@implementation YKFFIDO2GetAssertionAPDU

- (instancetype)initWithRequest:(YKFKeyFIDO2GetAssertionRequest *)request {
    YKFAssertAbortInit(request);
    YKFAssertAbortInit(request.rpId);
    YKFAssertAbortInit(request.clientDataHash);
    
    NSMutableDictionary *requestDictionary = [[NSMutableDictionary alloc] init];
    
    // RP
    requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyRp)] = YKFCBORTextString(request.rpId);
    
    // Client Data Hash
    requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyClientDataHash)] = YKFCBORByteString(request.clientDataHash);
    
    // Allow List
    if (request.allowList) {
        NSMutableArray *allowList = [[NSMutableArray alloc] initWithCapacity:request.allowList.count];
        for (YKFFIDO2PublicKeyCredentialDescriptor *credentialDescriptor in request.allowList) {
            [allowList addObject:[credentialDescriptor cborTypeObject]];
        }
        requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyAllowList)] = YKFCBORArray(allowList);
    }
    
    // Options
    if (request.options) {
        NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithCapacity:request.options.count];
        NSArray *optionsKeys = request.options.allKeys;
        for (NSString *optionKey in optionsKeys) {
            NSNumber *value = request.options[optionKey];
            options[YKFCBORTextString(optionKey)] = YKFCBORBool(value.boolValue);
        }
        requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyOptions)] = YKFCBORMap(options);
    }

    // Pin Auth
    if (request.pinAuth) {
        requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyPinAuth)] = YKFCBORByteString(request.pinAuth);
    }

    // Pin Protocol
    if (request.pinProtocol) {
        requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyPinProtocol)] = YKFCBORInteger(request.pinProtocol);
    }
    
    NSData *cborData = [YKFCBOREncoder encodeMap:YKFCBORMap(requestDictionary)];
    YKFAssertAbortInit(cborData);
    
    return [super initWithCommand:YKFFIDO2CommandGetAssertion data:cborData];
}

@end
