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

#import "YKFOATHCalculateAllAPDU.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFAssert.h"

static const UInt8 YKFOATHCalculateAllAPDUChallengeTag = 0x74;

@implementation YKFOATHCalculateAllAPDU

- (instancetype)initWithTimestamp:(NSDate *)timestamp {
    YKFAssertAbortInit(timestamp)
    
    NSMutableData *rawRequest = [[NSMutableData alloc] init];
    
    // Challenge
    
    time_t time = (time_t)[timestamp timeIntervalSince1970];
    time_t challengeTime = time / 30; // Calculate all assumes only 30s TOTPs
    
    [rawRequest ykf_appendUInt64EntryWithTag:YKFOATHCalculateAllAPDUChallengeTag value:challengeTime];
    
    // P2 is 0x01 for truncated response only
    return [super initWithCla:0x00 ins:YKFAPDUCommandInstructionOATHCalculateAll p1:0x00 p2:0x01 data:rawRequest type:YKFAPDUTypeShort];
}

@end
