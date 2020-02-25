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
#import "YKFKeyFIDO2Request.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFKeyFIDO2ChangePinRequest
 
 @abstract
    Request for changing the PIN on the FIDO2 key application. This request maps to the
    authenticatorClientPin command from CTAP2 protocol:
    https://fidoalliance.org/specs/fido-v2.0-rd-20180702/fido-client-to-authenticator-protocol-v2.0-rd-20180702.pdf
 
 @discussion
    The key FIDO2 application should have a PIN when executing this request. If the application
    doesn't have a PIN, this request will return an error and a set PIN request should be executed
    instead. After changing the PIN, a verify PIN request must be executed to re-authenticate
    the session.
 */
@interface YKFKeyFIDO2ChangePinRequest: YKFKeyFIDO2Request

/*!
 @abstract
    The old PIN which was set on the FIDO2 key application.
 
 @discussion
    The minimum PIN length accepted by the key is 4. If the PIN is shorter then 4 or longer then 255
    UTF8 encoded characters, the library will return an error.
 */
@property (nonatomic, readonly) NSString *pinOld;

/*!
 @abstract
    The new PIN to set on the FIDO2 key application.
 
 @discussion
    The minimum PIN length accepted by the key is 4. If the PIN is shorter then 4 or longer then 255
    UTF8 encoded characters, the library will return an error.
 */
@property (nonatomic, readonly) NSString *pinNew;

/*!
 @abstract
    Creates a new instance with the new PIN to set and the old PIN for verification.
 
 @param newPin
    The new PIN to set on the FIDO2 key application.
 
 @param oldPin
    The old PIN of the FIDO2 key application.
 */
- (nullable instancetype)initWithNewPin:(NSString *)newPin oldPin:(NSString *)oldPin NS_DESIGNATED_INITIALIZER;

/*
 Not available: use [initWithPin:] instead.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
