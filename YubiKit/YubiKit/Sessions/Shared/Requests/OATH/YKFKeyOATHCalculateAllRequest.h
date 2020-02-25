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
#import "YKFKeyOATHRequest.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFKeyOATHCalculateAllRequest
 
 @abstract
    Request for calculating all OATH credentials saved on the key. This request maps to the
    CALCULATE ALL command from YOATH protocol:
    https://developers.yubico.com/OATH/YKOATH_Protocol.html
 
 @discussion
    This calculates only TOTP credentials and returns the labels for HOTP credentials to avoid
    overloading the HOTP counters.
 
    Calculate All assumes that all TOTP credentials have a period of 30 seconds (default period)
    because the key command receives only one time challenge. For TOTP credentials which have a
    different period an explicit calculate request with the right period challenge needs to be
    performed afterwards.
 */
@interface YKFKeyOATHCalculateAllRequest: YKFKeyOATHRequest
@end

NS_ASSUME_NONNULL_END
