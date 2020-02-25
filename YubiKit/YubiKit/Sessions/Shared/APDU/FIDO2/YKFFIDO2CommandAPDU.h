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
#import "YKFAPDU.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, YKFFIDO2Command) {
    YKFFIDO2CommandMakeCredential      = 0x01,
    YKFFIDO2CommandGetAssertion        = 0x02,
    YKFFIDO2CommandCancel              = 0x03,
    YKFFIDO2CommandGetInfo             = 0x04,
    YKFFIDO2CommandClientPIN           = 0x06,
    YKFFIDO2CommandReset               = 0x07,
    YKFFIDO2CommandGetNextAssertion    = 0x08,
    YKFFIDO2CommandVendorFirst         = 0x40,
    YKFFIDO2CommandVendorLast          = 0xBF
};

@interface YKFFIDO2CommandAPDU: YKFAPDU

- (instancetype)initWithCommand:(YKFFIDO2Command)command data:(nullable NSData *)data;

@end

NS_ASSUME_NONNULL_END
