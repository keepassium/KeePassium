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

#import "YKFOATHSetCodeAPDU.h"
#import "YKFKeyOATHSetCodeRequest.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFOATHCredential.h"
#import "YKFAssert.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFNSDataAdditions+Private.h"

static const UInt8 YKFKeyOATHSetCodeAPDUKeyTag = 0x73;
static const UInt8 YKFKeyOATHSetCodeAPDUChallengeTag = 0x74;
static const UInt8 YKFKeyOATHSetCodeAPDUResponseTag = 0x75;

@implementation YKFOATHSetCodeAPDU

- (instancetype)initWithRequest:(YKFKeyOATHSetCodeRequest *)request salt:(NSData *)salt {
    YKFAssertAbortInit(request);
    YKFAssertAbortInit(salt.length);
    
    NSMutableData *rawRequest = [[NSMutableData alloc] init];
    
    // Password available - set authentication
    if (request.password.length) {
        NSData *keyData = [[request.password dataUsingEncoding:NSUTF8StringEncoding] ykf_deriveOATHKeyWithSalt:salt];
        UInt8 algorithm = YKFOATHCredentialTypeTOTP | YKFOATHCredentialAlgorithmSHA1;
        
        [rawRequest ykf_appendEntryWithTag:YKFKeyOATHSetCodeAPDUKeyTag headerBytes:@[@(algorithm)] data:keyData];
        
        // Challenge
        
        UInt8 challengeBuffer[8];
        arc4random_buf(challengeBuffer, 8);
        NSData *challenge = [NSData dataWithBytes:challengeBuffer length:8];
        [rawRequest ykf_appendEntryWithTag:YKFKeyOATHSetCodeAPDUChallengeTag data:challenge];
        
        // Response
        
        NSData *response = [challenge ykf_oathHMACWithKey:keyData];
        [rawRequest ykf_appendEntryWithTag:YKFKeyOATHSetCodeAPDUResponseTag data:response];
    } else {
        // Password empty - remove authentication
        [rawRequest ykf_appendByte:YKFKeyOATHSetCodeAPDUKeyTag];
        [rawRequest ykf_appendByte:0x00];
    }
        
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionOATHSet p1:0 p2:0 data:rawRequest type:YKFAPDUTypeShort];
}

@end
