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

#import "YKFU2FRegisterAPDU.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFNSDataAdditions.h"
#import "YKFKeyU2FRegisterRequest.h"
#import "YKFAssert.h"

#import "YKFKeyU2FRequest+Private.h"
#import "YKFNSDataAdditions+Private.h"

static const UInt8 YKFU2FRegisterAPDUEnforceUserPresenceAndSign = 0x03;

@implementation YKFU2FRegisterAPDU

- (instancetype)initWithU2FRegisterRequest:(YKFKeyU2FRegisterRequest *)request {
    YKFAssertAbortInit(request);
        
    NSString *appId = request.appId;
    YKFAssertAbortInit(appId);
        
    NSString *clientData = request.clientData;
    YKFAssertAbortInit(clientData);
    
    NSData *challengeSHA256 = [[clientData dataUsingEncoding:NSUTF8StringEncoding] ykf_SHA256];
    YKFAssertAbortInit(challengeSHA256);
    
    NSData *applicationSHA256 = [[appId dataUsingEncoding:NSUTF8StringEncoding] ykf_SHA256];
    YKFAssertAbortInit(applicationSHA256);
    
    NSMutableData *rawU2fRequest = [[NSMutableData alloc] init];
    
    [rawU2fRequest appendData:challengeSHA256];
    [rawU2fRequest appendData:applicationSHA256];
    
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionU2FRegister p1:YKFU2FRegisterAPDUEnforceUserPresenceAndSign p2:0 data:rawU2fRequest type:YKFAPDUTypeExtended];
}

@end
