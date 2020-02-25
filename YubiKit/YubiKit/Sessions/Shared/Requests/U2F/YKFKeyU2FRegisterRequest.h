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
 @class YKFKeyU2FRegisterRequest
 
 @abstract
    Data model which contains the required information by the key to perform an U2F registration request.
 */
@interface YKFKeyU2FRegisterRequest: YKFKeyU2FRequest

/*!
 @property challenge
 
 @abstract
    The U2F registration challenge which is usually received from the authentication server.
 @discussion
    Registration challenge message format as defined by the FIDO Alliance specifications
    ---
    https://fidoalliance.org/specs/fido-u2f-v1.2-ps-20170411/fido-u2f-raw-message-formats-v1.2-ps-20170411.html#registration-messages
 */
@property (nonatomic, readonly, nonnull) NSString *challenge;

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
 @method initWithChallenge:appId:
 
 @abstract
    The designated initializer for this type of request. Both challenge and appId parameters are required to properly
    perfrom a registration request with the key.
 
 @param challenge
    See the challenge property documentation on YKFKeyU2FRegisterRequest.
 @param appId
    See the appId property documentation on YKFKeyU2FRegisterRequest.
 */
- (nullable instancetype)initWithChallenge:(nonnull NSString *)challenge appId:(nonnull NSString *)appId NS_DESIGNATED_INITIALIZER;

/*
 Not available: use the designated initializer.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
