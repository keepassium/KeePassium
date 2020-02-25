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
#import "YKFFIDO2Type.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 @abstract
    The response to a FIDO2 Get Assertion request. The result contains the data structures
    defined in the CTAP2 authenticatorGetAssertion command response.
 */
@interface YKFKeyFIDO2GetAssertionResponse: NSObject

/*!
 @abstract
    Contains the credential identifier whose private key was used to generate the assertion.
 
 @discussion
    This property is optional. It may be omitted by the key if the allowList from the request has
    exactly one credential.
 */
@property (nonatomic, readonly, nullable) YKFFIDO2PublicKeyCredentialDescriptor *credential;

/*!
 @abstract
    The signed-over contextual bindings made by the authenticator, as specified in WebAuthN.
 
 @discussion
    This property is not optional. The key must reply with the authData when the Get Assertion
    request was successful.
 */
@property (nonatomic, readonly) NSData *authData;

/*!
 @abstract
    The assertion signature produced by the authenticator, as specified in WebAuthN.
 
 @discussion
    This property is not optional. The key must reply with a signature when the Get Assertion
    request was successful.
 */
@property (nonatomic, readonly) NSData *signature;

/*!
 @abstract
    Contains the user account information.
 
 @discussion
    This property is optional. The key may not provide the user data structure
    in the response. See CTAP2 specifications for more details.
 */
@property (nonatomic, readonly, nullable) YKFFIDO2PublicKeyCredentialUserEntity *user;

/*!
 @abstract
    The total number of account credentials for the RP.
 
 @discussion
    This property is optional. The key may not provide the number of credentials
    in some cases. See CTAP2 specifications for more details.
 */
@property (nonatomic, readonly) NSInteger numberOfCredentials;

/*!
 @abstract
    The raw, unparsed CBOR response of the request.
 
 @discussion
    This value is useful when the server implementation will handle the parsing of the response and requires
    the unparsed payload received from the key.
 */
@property (nonatomic, readonly) NSData *rawResponse;

/*
 Not available: the response will be created by the library.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
