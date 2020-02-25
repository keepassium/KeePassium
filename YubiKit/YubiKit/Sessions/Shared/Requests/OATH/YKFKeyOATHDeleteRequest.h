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
#import "YKFOATHCredential.h"

/*!
 @class YKFKeyOATHDeleteRequest
 
 @abstract
    Request for deleting an OATH credential saved on the key. This request maps to the DELETE
    command from YOATH protocol:
    https://developers.yubico.com/OATH/YKOATH_Protocol.html
 */
@interface YKFKeyOATHDeleteRequest: YKFKeyOATHRequest

/*!
 The credential for the request. The credential must provide at least the label and
 period (TOTP) properties for the request to succeed. This value is set at initialization.
 */
@property (nonatomic, readonly, nonnull) YKFOATHCredential *credential;

/*!
 @method initWithCredential:
 
 @abstract
    The designated initializer for this type of request. The credential parameter is required.
 
 @param credential
    The credential for the request. The credential must be already added to the key when calling this request.
 */
- (nullable instancetype)initWithCredential:(nonnull YKFOATHCredential*)credential NS_DESIGNATED_INITIALIZER;

/*
 Not available: use [initWithCredential:].
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
