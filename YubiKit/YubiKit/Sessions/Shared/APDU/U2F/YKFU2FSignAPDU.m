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

#import "YKFU2FSignAPDU.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFNSDataAdditions.h"
#import "YKFAssert.h"

#import "YKFNSDataAdditions+Private.h"
#import "YKFKeyU2FRequest+Private.h"

static const UInt8 YKFU2FSignAPDUKeyHandleSize = 64;
static const UInt8 YKFU2FSignAPDUEnforceUserPresenceAndSign = 0x03;

@implementation YKFU2FSignAPDU

- (instancetype)initWithU2fSignRequest:(YKFKeyU2FSignRequest *)request {
    YKFAssertAbortInit(request);
        
    NSString *keyHandle = request.keyHandle;
    YKFAssertAbortInit(keyHandle);
    
    NSString *appId = request.appId;
    YKFAssertAbortInit(appId);
        
    NSString *clientData = request.clientData;
    YKFAssertAbortInit(clientData);
    
    NSData *challengeSHA256 = [[clientData dataUsingEncoding:NSUTF8StringEncoding] ykf_SHA256];
    YKFAssertAbortInit(challengeSHA256);
    
    NSData *applicationSHA256 = [[appId dataUsingEncoding:NSUTF8StringEncoding] ykf_SHA256];
    YKFAssertAbortInit(applicationSHA256);
    
    NSMutableData *rawU2FRequest = [NSMutableData data];
    
    [rawU2FRequest appendData:challengeSHA256];
    [rawU2FRequest appendData:applicationSHA256];
    
    NSData *keyHandleData = [[NSData alloc] ykf_initWithWebsafeBase64EncodedString:keyHandle dataLength:YKFU2FSignAPDUKeyHandleSize];
    UInt8 keyHandleLength = [keyHandleData length];
    YKFAssertAbortInit(keyHandle);
    YKFAssertAbortInit(keyHandleLength <= UINT8_MAX);
    
    [rawU2FRequest appendBytes:&keyHandleLength length:1];
    [rawU2FRequest appendData:keyHandleData];
    
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionU2FSign p1:YKFU2FSignAPDUEnforceUserPresenceAndSign p2:0 data:rawU2FRequest type:YKFAPDUTypeExtended];
}

@end
