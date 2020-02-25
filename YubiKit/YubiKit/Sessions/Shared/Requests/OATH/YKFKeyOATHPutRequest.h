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
#import "YKFOATHCredential.h"
#import "YKFKeyOATHRequest.h"

/*!
 @class YKFKeyOATHPutRequest
 
 @abstract
    Request for adding a new OATH credential to the key or to override an existig credential
    from the key. This request maps to the PUT command from YOATH protocol:
    https://developers.yubico.com/OATH/YKOATH_Protocol.html
 */
@interface YKFKeyOATHPutRequest: YKFKeyOATHRequest

/*!
 The credential to be added to the key. This property is set at initialization.
 */
@property (nonatomic, readonly, nonnull) YKFOATHCredential *credential;

/*!
 @method initWithCredential:
 
 @abstract
    The designated initializer for this type of request. The credential parameter is required.
 
 @param credential
    The credential to be added to the key. If a credential with the same type, account and issuer
    exists on the key, the old credential is overriden.
 */
- (nullable instancetype)initWithCredential:(nonnull YKFOATHCredential *)credential NS_DESIGNATED_INITIALIZER;

/*
 Not available: use [initWithCredential:].
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
