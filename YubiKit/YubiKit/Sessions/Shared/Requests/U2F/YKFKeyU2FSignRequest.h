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
#import "YKFKeyU2FRequest.h"

/*!
 @class YKFKeyU2FSignRequest
 
 @abstract
    Data model which contains the required information by the key to perform an U2F sign request.
 */
@interface YKFKeyU2FSignRequest : YKFKeyU2FRequest

/*!
 @property challenge
 
 @abstract
    The U2F authentication challenge which is usually received from the authentication server.
 @discussion
    Authentication challenge message format as defined by the FIDO Alliance specifications
    ---
    https://fidoalliance.org/specs/fido-u2f-v1.2-ps-20170411/fido-u2f-raw-message-formats-v1.2-ps-20170411.html#authentication-messages
 */
@property (nonatomic, readonly, nonnull) NSString *challenge;

/*!
 @property keyHandle
 
 @abstract
    The U2F authentication keyHandle which is usually received from the authentication server and used by
    the hardware key to identify the required cryptographic key for signing.
 @discussion
    Format as defined by the FIDO Alliance specifications
    ---
    https://fidoalliance.org/specs/fido-u2f-v1.2-ps-20170411/fido-u2f-raw-message-formats-v1.2-ps-20170411.html#authentication-messages
 */
@property (nonatomic, readonly, nonnull) NSString *keyHandle;

/*!
 @property appId
 
 @abstract
    The application ID (sometimes reffered as origin or facet ID) as described by the U2F standard.
    This is usually a domain which belongs to the application.
 @discussion
    Documentation for the application ID format
    ---
    https://developers.yubico.com/U2F/App_ID.html
 */
@property (nonatomic, readonly, nonnull) NSString *appId;

/*!
 @method initWithChallenge:keyHandle:appId:
 
 @abstract
    The designated initializer for this type of request. All parameters are required to properly perfrom a sign request with the key.
 
 @param challenge
    See the challenge property documentation on YKFKeyU2FSignRequest.
 @param keyHandle
    See the keyHandle property documentation on YKFKeyU2FSignRequest.
 @param appId
    See the appId property documentation on YKFKeyU2FSignRequest.
 */
- (nullable instancetype)initWithChallenge:(nonnull NSString *)challenge keyHandle:(nonnull NSString *)keyHandle appId:(nonnull NSString *)appId NS_DESIGNATED_INITIALIZER;

/*
 Not available: use the designated initializer.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
