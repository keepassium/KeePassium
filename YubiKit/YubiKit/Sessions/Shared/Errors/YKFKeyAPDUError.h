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

#import "YKFKeySessionError.h"

typedef NS_ENUM(NSUInteger, YKFKeyAPDUErrorCode) {
    YKFKeyAPDUErrorCodeNoError                  = 0x9000,
    YKFKeyAPDUErrorCodeFIDO2TouchRequired       = 0x9100,
    YKFKeyAPDUErrorCodeConditionNotSatisfied    = 0x6985,
    
    YKFKeyAPDUErrorCodeAuthenticationRequired   = 0x6982,
    YKFKeyAPDUErrorCodeDataInvalid              = 0x6984,
    YKFKeyAPDUErrorCodeWrongLength              = 0x6700,
    YKFKeyAPDUErrorCodeWrongData                = 0x6A80,
    YKFKeyAPDUErrorCodeInsNotSupported          = 0x6D00,
    YKFKeyAPDUErrorCodeCLANotSupported          = 0x6E00,
    YKFKeyAPDUErrorCodeUnknown                  = 0x6F00,
    YKFKeyAPDUErrorCodeMissingFile              = 0x6A82,
    
    // Application/Applet short codes
    
    YKFKeyAPDUErrorCodeMoreData                 = 0x61 // 0x61XX
};

NS_ASSUME_NONNULL_BEGIN

@interface YKFKeyAPDUError: YKFKeySessionError
@end

NS_ASSUME_NONNULL_END
