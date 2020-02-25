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

#import "YKFSelectFIDO2ApplicationAPDU.h"
#import "YKFAPDUCommandInstruction.h"

static const NSUInteger YKFFido2AIDSize = 8;
static const UInt8 YKFFido2AID[YKFFido2AIDSize] = {0xA0, 0x00, 0x00, 0x06, 0x47, 0x2F, 0x00, 0x01};

@implementation YKFSelectFIDO2ApplicationAPDU

- (instancetype)init {
    NSData *data = [NSData dataWithBytes:YKFFido2AID length:YKFFido2AIDSize];
    return [super initWithCla:0x00 ins:YKFAPDUCommandInstructionSelectApplication p1:0x04 p2:0x00 data:data type:YKFAPDUTypeShort];
}

@end
