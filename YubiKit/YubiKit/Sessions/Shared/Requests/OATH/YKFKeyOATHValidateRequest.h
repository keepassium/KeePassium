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

/*!
 @class YKFKeyOATHValidateRequest
 
 @abstract
    Request for authehticating on the OATH application from the key. This request maps to the
    VALIDATE command from YOATH protocol:
    https://developers.yubico.com/OATH/YKOATH_Protocol.html
 */
@interface YKFKeyOATHValidateRequest: YKFKeyOATHRequest

/*!
 The password to validate against the OATH application. This property is set at initialization.
 */
@property (nonatomic, readonly, nonnull) NSString *password;

/*!
 @method initWithPassword:
 
 @abstract
    The designated initializer for this type of request. The password parameter is required.
 
 @param password
    The password to authenticate on the key OATH application. The password may not be an
    empty string.
 */
- (nullable instancetype)initWithPassword:(nonnull NSString *)password NS_DESIGNATED_INITIALIZER;

/*
 Not available: use [initWithPassword:].
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
