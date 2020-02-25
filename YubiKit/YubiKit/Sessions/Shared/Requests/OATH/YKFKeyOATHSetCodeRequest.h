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
 @class YKFKeyOATHSetCodeRequest
 
 @abstract
    Request for setting a PIN on the OATH application from the key. This request maps
    to the SET CODE command from YOATH protocol:
    https://developers.yubico.com/OATH/YKOATH_Protocol.html
 */
@interface YKFKeyOATHSetCodeRequest: YKFKeyOATHRequest

/*!
 The password to set on the OATH application. This property is set at initialization.
 */
@property (nonatomic, readonly, nonnull) NSString *password;

/*!
 @method initWithPassword:
 
 @abstract
    The designated initializer for this type of request. The password parameter is required.
 
 @param password
    The password to set on the OATH application. The password can be an empty string. If the
    password is an empty string, the authentication will be removed.
 */
- (nullable instancetype)initWithPassword:(nonnull NSString *)password NS_DESIGNATED_INITIALIZER;

/*
 Not available: use [initWithPassword:].
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
