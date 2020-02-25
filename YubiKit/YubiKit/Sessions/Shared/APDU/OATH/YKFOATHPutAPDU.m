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

#import "YKFOATHPutAPDU.h"
#import "YKFKeyOATHPutRequest.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFAssert.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFOATHCredential+Private.h"

typedef NS_ENUM(NSUInteger, YKFOATHPutCredentialAPDUTag) {
    YKFOATHPutCredentialAPDUTagName = 0x71,
    YKFOATHPutCredentialAPDUTagKey = 0x73,
    YKFOATHPutCredentialAPDUTagProperty = 0x78,
    YKFOATHPutCredentialAPDUTagCounter = 0x7A // Only HOTP
};

typedef NS_ENUM(NSUInteger, YKFOATHPutCredentialAPDUProperty) {
    YKFOATHPutCredentialAPDUPropertyTouch = 0x02
};

@implementation YKFOATHPutAPDU

- (instancetype)initWithRequest:(YKFKeyOATHPutRequest *)request {
    YKFAssertAbortInit(request);
    
    NSMutableData *rawRequest = [[NSMutableData alloc] init];
    
    // Name - max 64 bytes
    
    NSString *name = request.credential.key;
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    [rawRequest ykf_appendEntryWithTag:YKFOATHPutCredentialAPDUTagName data:nameData];
    
    // Key
    
    NSData *secret = request.credential.secret;
    UInt8 keyAlgorithm = request.credential.algorithm | request.credential.type;
    UInt8 keyDigits = request.credential.digits;
    
    [rawRequest ykf_appendEntryWithTag:YKFOATHPutCredentialAPDUTagKey headerBytes:@[@(keyAlgorithm), @(keyDigits)] data:secret];
    
    // Touch
    if (request.credential.requiresTouch) {
        [rawRequest ykf_appendByte:YKFOATHPutCredentialAPDUTagProperty];
        [rawRequest ykf_appendByte:YKFOATHPutCredentialAPDUPropertyTouch];
    }
    
    // Counter if HOTP
    if (request.credential.type == YKFOATHCredentialTypeHOTP) {
        [rawRequest ykf_appendUInt32EntryWithTag:YKFOATHPutCredentialAPDUTagCounter value:request.credential.counter];
    }
    
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionOATHPut p1:0 p2:0 data:rawRequest type:YKFAPDUTypeShort];
}

@end
