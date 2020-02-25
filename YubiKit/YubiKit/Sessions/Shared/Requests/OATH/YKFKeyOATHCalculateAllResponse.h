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

/*!
 @class YKFOATHCredentialCalculateResult
 
 @abstract
    The response for a credential from Calculate All request. The result contains
    both some credential information and the calculation for a TOTP credential.
 */
@interface YKFOATHCredentialCalculateResult: NSObject

/*!
 The type of the credential (TOTP or HOTP).
 */
@property (nonatomic, assign, readonly) YKFOATHCredentialType type;

/*!
 The account name associated with the credential. This value was set when the credential
 was added to the key.
 */
@property (nonatomic, readonly, nonnull) NSString *account;

/*!
 The issuer associated with the credential. This value was set when the credential was
 added to the key.
 */
@property (nonatomic, readonly, nullable) NSString *issuer;

/*!
 The validity period for the credential, when TOTP. For HOTP this property has the value 0.
 */
@property (nonatomic, assign, readonly) NSUInteger period;

/*!
 The validity date interval for the credential, when TOTP. For HOTP this property is the
 interval [<time of request>, <date distant future>] because an HOTP credential does not have
 an expiration date.
 */
@property (nonatomic, readonly, nonnull) NSDateInterval *validity;

/*!
 The OTP value of the credential. Calculate All does not calculate HOTP credentials to not overload
 the counters. When the credential is HOTP, the value of this property is nil. To calculate HOTP
 credentials an explicit calculate request with the credential needs to pe performed.
 */
@property (nonatomic, readonly, nullable) NSString *otp;

/*!
 The credential requires the user to touch the key to generate it. The property returns YES for
 HOTP credentials and for TOTP credentials created with Touch Required option.
 */
@property (nonatomic, readonly) BOOL requiresTouch;

@end

/*!
 @class YKFKeyOATHCalculateAllResponse
 
 @abstract
    Response from Calculate All request for calculating all OATH credentials saved on the key.
 */
@interface YKFKeyOATHCalculateAllResponse : NSObject

/*!
 The list of credentials (YKFOATHCredentialCalculateResult type) with the calculated OTPs.
 If the key does not contain any OATH credentials, this property returns an empty array.
 */
@property (nonatomic, readonly, nonnull) NSArray *credentials;

/*
 Not available: the library will create a response as the result of the Calculate All request.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end

