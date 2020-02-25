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

#import "YKFSelectOATHApplicationAPDU.h"
#import "YKFAPDUCommandInstruction.h"

// SELECT APDU format: https://developers.yubico.com/OATH/YKOATH_Protocol.html
static const NSUInteger YKFOathAIDSize = 7;
static const UInt8 YKFOathAID[YKFOathAIDSize] = {0xA0, 0x00, 0x00, 0x05, 0x27, 0x21, 0x01};

@implementation YKFSelectOATHApplicationAPDU

- (instancetype)init {
    NSData *data = [NSData dataWithBytes:YKFOathAID length:YKFOathAIDSize];
    return [super initWithCla:0x00 ins:YKFAPDUCommandInstructionSelectApplication p1:0x04 p2:0x00 data:data type:YKFAPDUTypeShort];
}

@end
