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
#import "YKFFIDO2Type.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name Options Keys
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Resident Key option key to set in the request options dictionary.
 
 @discusion
    Instructs the authenticator to store the key material on the device. Set this key in the options dictionary of
    the request when necessary.
 */
extern NSString* const YKFKeyFIDO2MakeCredentialRequestOptionRK;

/*!
 @abstract
    User Verification option key to set in the request options dictionary.
 
 @discussion
    Instructs the authenticator to require a gesture that verifies the user to complete the request. Examples of such
    gestures are fingerprint scan or a PIN. Set this key in the options dictionary of the request when necessary.
 */
extern NSString* const YKFKeyFIDO2MakeCredentialRequestOptionUV;

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFKeyFIDO2MakeCredentialRequest
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFKeyFIDO2MakeCredentialRequest
 
 @abstract
    Request for creating/updating a FIDO2 credential on the key. This request maps to the
    authenticatorMakeCredential command from CTAP2 protocol:
    https://fidoalliance.org/specs/fido-v2.0-rd-20180702/fido-client-to-authenticator-protocol-v2.0-rd-20180702.pdf
 */
@interface YKFKeyFIDO2MakeCredentialRequest: YKFKeyFIDO2Request

/*!
 @abstract
    Hash of the ClientData contextual binding specified by host.
 
 @discussion
    This property is required by the key to fulfil the request. The value should be a SHA256 of the received
    Client Data from the WebAuthN server. If missing, the FIDO2 Service will return an error when trying to
    execute the request.
 */
@property (nonatomic) NSData *clientDataHash;

/*!
 @abstract
    This property describes a Relying Party with which the new public key credential will be associated.
 
 @discussion
    This property is required by the key to fulfil the request. If missing, the FIDO2 Service will return
    an error when trying to execute the request.
 */
@property (nonatomic) YKFFIDO2PublicKeyCredentialRpEntity *rp;

/*!
 @abstract
    This property describes the user account to which the new public key credential will be associated at the RP.
 
 @discussion
    This property is required by the key to fulfil the request. If missing, the FIDO2 Service will return
    an error when trying to execute the request.
 */
@property (nonatomic) YKFFIDO2PublicKeyCredentialUserEntity *user;

/*!
 @abstract
    A list of YKFFIDO2PublicKeyCredentialParam objects with algorithm identifiers which are values registered in
    the IANA COSE Algorithms registry. This sequence is ordered from most preferred (by the RP) to least preferred.
 
 @discussion
    This property is required by the key to fulfil the request. If missing, the FIDO2 Service will return
    an error when trying to execute the request.
 */
@property (nonatomic) NSArray *pubKeyCredParams;

/*!
 @abstract
    A list of YKFFIDO2PublicKeyCredentialDescriptor to be excluded when creating a new credential.
 
 @discussion
    The authenticator returns an error if the authenticator already contains one of the credentials enumerated in
    this sequence. This allows RPs to limit the creation of multiple credentials for the same account on a single
    authenticator. This property is optional.
 */
@property (nonatomic, nullable) NSArray *excludeList;

/*!
 @discussion
    Parameters to influence authenticator operation, as specified in in the table below.
    This parameter is optional.
 
    @code
    Key           | Default value      | Definition
    ----------------------------------------------------------------------------------------
    rk            | false              | resident key: Instructs the authenticator to store
                                         the key material on the device.
    ----------------------------------------------------------------------------------------
    uv            | false              | user verification: Instructs the authenticator to
                                         require a gesture that verifies the user to complete
                                         the request. Examples of such gestures are fingerprint
                                         scan or a PIN.
    ----------------------------------------------------------------------------------------
    up            | INVALID            | user presence: The key will return an error if this
                                         parameter is set when creating a credential.
                                         UP cannot be configured when creating a credential
                                         because it's implicitly set to true.
    @endcode
 */
@property (nonatomic, nullable) NSDictionary *options;

@end

NS_ASSUME_NONNULL_END
