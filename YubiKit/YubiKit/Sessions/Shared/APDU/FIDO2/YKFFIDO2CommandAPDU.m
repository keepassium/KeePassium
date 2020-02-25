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

#import "YKFFIDO2CommandAPDU.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFAssert.h"

@implementation YKFFIDO2CommandAPDU

- (instancetype)initWithCommand:(YKFFIDO2Command)command data:(NSData *)data {
    BOOL isFido2Command = command >= 0x01 && command <= 0x08 && command != 0x05;
    BOOL isVendorCommand = command >= 0x40 && command <= 0xBF;
    YKFAssertAbortInit(isFido2Command || isVendorCommand);
    
    NSMutableData *commandData = [[NSMutableData alloc] initWithCapacity:data.length + 1];
    [commandData ykf_appendByte:command];
    
    if (data.length) {
        [commandData appendData:data];
        return [super initWithCla:0x80 ins:YKFAPDUCommandInstructionFIDO2Msg
                               p1:0x80 p2:0x00 data:commandData type:YKFAPDUTypeExtended];
    }
    
    return [super initWithCla:0x80 ins:YKFAPDUCommandInstructionFIDO2Msg
                           p1:0x80 p2:0x00 data:commandData type:YKFAPDUTypeShort];
}

@end
