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

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, YKFAPDUCommandInstruction) {
    YKFAPDUCommandInstructionNone = 0x00,
    
    /* U2F instructions */
    YKFAPDUCommandInstructionU2FRegister = 0x01,
    YKFAPDUCommandInstructionU2FSign = 0x02,
    YKFAPDUCommandInstructionU2FVersion = 0x03,
    YKFAPDUCommandInstructionU2FPing = 0x40,
    YKFAPDUCommandInstructionU2FCustom = 0xFF,
    
    /* FIDO2 instructions */
    YKFAPDUCommandInstructionFIDO2Msg = 0x10,
    YKFAPDUCommandInstructionFIDO2GetResponse = 0x11,
    
    /* OATH instructions */
    YKFAPDUCommandInstructionOATHPut = 0x01,
    YKFAPDUCommandInstructionOATHDelete = 0x02,
    YKFAPDUCommandInstructionOATHSet = 0x03,
    YKFAPDUCommandInstructionOATHReset = 0x04,
    YKFAPDUCommandInstructionOATHList = 0xA1,
    YKFAPDUCommandInstructionOATHCalculate = 0xA2,
    YKFAPDUCommandInstructionOATHValidate = 0xA3,
    YKFAPDUCommandInstructionOATHCalculateAll = 0xA4,
    YKFAPDUCommandInstructionOATHSendRemaining = 0xA5,
    
    /* Application selection */
    YKFAPDUCommandInstructionSelectApplication = 0xA4
};
