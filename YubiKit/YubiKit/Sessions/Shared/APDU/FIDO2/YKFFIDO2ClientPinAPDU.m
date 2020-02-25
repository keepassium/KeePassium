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

#import "YKFFIDO2ClientPinAPDU.h"
#import "YKFKeyFIDO2ClientPinRequest.h"
#import "YKFCBOREncoder.h"
#import "YKFCBORType.h"
#import "YKFAssert.h"

typedef NS_ENUM(NSUInteger, YKFFIDO2ClientPinAPDUKey) {
    YKFFIDO2ClientPinAPDUKeyPinProtocol     = 0x01,
    YKFFIDO2ClientPinAPDUKeySubCommand      = 0x02,
    YKFFIDO2ClientPinAPDUKeyKeyAgreement    = 0x03,
    YKFFIDO2ClientPinAPDUKeyPinAuth         = 0x04,
    YKFFIDO2ClientPinAPDUKeyPinEnc          = 0x05,
    YKFFIDO2ClientPinAPDUKeyPinHashEnc      = 0x06
};

@implementation YKFFIDO2ClientPinAPDU

- (instancetype)initWithRequest:(YKFKeyFIDO2ClientPinRequest *)request {
    YKFAssertAbortInit(request);
    YKFAssertAbortInit(request.subCommand >= 0x01 && request.subCommand <= 0x05)
    
    if (request.subCommand == YKFKeyFIDO2ClientPinRequestSubCommandGetKeyAgreement) {
        YKFAssertAbortInit(request.keyAgreement);
    } else if (request.subCommand == YKFKeyFIDO2ClientPinRequestSubCommandGetPINToken) {        
        YKFAssertAbortInit(request.pinHashEnc);
    }
    
    NSMutableDictionary *requestDictionary = [[NSMutableDictionary alloc] init];
    
    requestDictionary[YKFCBORInteger(YKFFIDO2ClientPinAPDUKeyPinProtocol)] = YKFCBORInteger(request.pinProtocol);
    requestDictionary[YKFCBORInteger(YKFFIDO2ClientPinAPDUKeySubCommand)] = YKFCBORInteger(request.subCommand);
    
    if (request.keyAgreement) {
        requestDictionary[YKFCBORInteger(YKFFIDO2ClientPinAPDUKeyKeyAgreement)] = request.keyAgreement;
    }
    if (request.pinAuth) {
        requestDictionary[YKFCBORInteger(YKFFIDO2ClientPinAPDUKeyPinAuth)] = YKFCBORByteString(request.pinAuth);
    }
    if (request.pinEnc) {
        requestDictionary[YKFCBORInteger(YKFFIDO2ClientPinAPDUKeyPinEnc)] = YKFCBORByteString(request.pinEnc);
    }
    if (request.pinHashEnc) {
        requestDictionary[YKFCBORInteger(YKFFIDO2ClientPinAPDUKeyPinHashEnc)] = YKFCBORByteString(request.pinHashEnc);
    }
    
    NSData *cborData = [YKFCBOREncoder encodeMap:YKFCBORMap(requestDictionary)];
    YKFAssertAbortInit(cborData);
    
    return [super initWithCommand:YKFFIDO2CommandClientPIN data:cborData];
}

@end
