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

#import "YKFKeyFIDO2GetAssertionRequest.h"


@interface YKFKeyFIDO2GetAssertionRequest()

/*!
 @abstract
    First 16 bytes of HMAC-SHA-256 of clientDataHash using pinToken which platform got from the
    authenticator: HMAC-SHA256(pinToken, clientDataHash).
 
 @discussion
    This parameter is optional.
 */
@property (nonatomic, nullable) NSData *pinAuth;

/*!
 @abstract
    PIN protocol version selected by client.
 
 @discussion
    This parameter is optional. Currently the key supports only pin protocol version 1. If not
    specified the key will use version 1 as default.
 */
@property (nonatomic) NSUInteger pinProtocol;

@end
