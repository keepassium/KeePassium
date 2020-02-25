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

#import "YKFOATHCalculateAPDU.h"
#import "YKFKeyOATHCalculateRequest.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFAssert.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFOATHCredential+Private.h"

static const UInt8 YKFOATHCalculateAPDUNameTag = 0x71;
static const UInt8 YKFOATHCalculateAPDUChallengeTag = 0x74;

@implementation YKFOATHCalculateAPDU

- (nullable instancetype)initWithRequest:(nonnull YKFKeyOATHCalculateRequest *)request timestamp:(NSDate *)timestamp {
    YKFAssertAbortInit(request);
    YKFAssertAbortInit(timestamp);
    
    NSMutableData *rawRequest = [[NSMutableData alloc] init];
    
    // Name
    NSString *name = request.credential.key;
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    
    [rawRequest ykf_appendEntryWithTag:YKFOATHCalculateAPDUNameTag data:nameData];
    
    // Challenge
    
    if (request.credential.type == YKFOATHCredentialTypeTOTP) {
        time_t time = (time_t)[timestamp timeIntervalSince1970];
        time_t challengeTime = time / request.credential.period;
        
        [rawRequest ykf_appendUInt64EntryWithTag:YKFOATHCalculateAPDUChallengeTag value:challengeTime];
    } else {
        // For HOTP the challenge is 0
        [rawRequest ykf_appendByte:YKFOATHCalculateAPDUChallengeTag];
        [rawRequest ykf_appendByte:0];
    }
    
    // P2 is 0x01 for truncated response only
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionOATHCalculate p1:0 p2:0x01 data:rawRequest type:YKFAPDUTypeShort];
}

@end
