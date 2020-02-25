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

@class YKFFIDO2AuthenticatorData;

NS_ASSUME_NONNULL_BEGIN

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFKeyFIDO2MakeCredentialResponse
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    The response to a FIDO2 Make Credential request. The result contains the data structures defined in
    the CTAP2 authenticatorMakeCredential command response.
 
 @discussion
    For convenience, there are some derived properties which can be used on the client to check some parsed
    parameters of the response, but they should not be necessary in the client-server communication.
 */
@interface YKFKeyFIDO2MakeCredentialResponse: NSObject

/*!
 The authenticator data object.
 */
@property (nonatomic, readonly) NSData *authData;

/*!
 The attestation statement format identifier.
 */
@property (nonatomic, readonly) NSString *fmt;

/*!
 The attestation statement, whose format is identified by the "fmt" object member. The client should treat it
 as an opaque object.
 */
@property (nonatomic, readonly) NSData *attStmt;

/*!
 @abstract
    The raw, unparsed CBOR response of the request.
 
 @discussion
    This value is useful when the server implementation will handle the parsing of the response and requires
    the unparsed payload received from the key.
 */
@property (nonatomic, readonly) NSData *rawResponse;

/*
 * Derived Properties
 */

/*!
 @abstract
    Returns the attestation object as defined in the CTAP2 specifictions.
 
 @discussion
    Currently this property provides the same CBOR map as the rawResponse. In this map the attestation
    object is using numeric keys for fmt, authData and attStmt, as defined by the CTAP2 specification:
    https://fidoalliance.org/specs/fido-v2.0-ps-20190130/fido-client-to-authenticator-protocol-v2.0-ps-20190130.html#responses
 */
@property (nonatomic, readonly) NSData *ctapAttestationObject;

/*!
 @abstract
    Returns the CTAP2 attestation object in WebAuthN format.
 
 @discussion
    This property returns a CBOR map with the content identical to the ctapAttestationObject, except
    for the keys, which are text, as defined by the WebAuthN specifications:
    https://developer.mozilla.org/en-US/docs/Web/API/AuthenticatorAttestationResponse/attestationObject
 */
@property (nonatomic, readonly) NSData *webauthnAttestationObject;

/*!
 @abstract
    The authenticatorData is a derived property which will be lazy created by parsing the authData property value.
 
 @discussion
    The information provided by this property should not be required by the server. The client should treat the
    Make Credential result as an opaque object and send it to the authentication server to be processed. However,
    the information provided by this object can be used by the client to inspect some authenticator and response
    properties.
 */
@property (nonatomic, readonly, nullable) YKFFIDO2AuthenticatorData *authenticatorData;

/*
 Not available: the response will be created by the library.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFFIDO2AuthenticatorData
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFFIDO2AuthenticatorData
 
 @abstract
    Provides a list of authenticator parameters as defined in WebAuthN authenticator data structure:
    https://www.w3.org/TR/webauthn/#authenticator-data
 */
@interface YKFFIDO2AuthenticatorData: NSObject

/*!
 SHA-256 hash of the RP ID the credential is scoped to.
 */
@property (nonatomic, readonly) NSData *rpIdHash;

/*!
 A bit field of flags which indicate some of the make credential result parameters like user presence,
 user verification, presence of attestation data, etc.
 */
@property (nonatomic, readonly) UInt8 flags;

/*!
 The signature counter.
 */
@property (nonatomic, readonly) UInt32 signCount;

/*!
 The AAGUID of the authenticator. This is a 16 bytes identifier.
 */
@property (nonatomic, readonly, nullable) NSData *aaguid;

/*!
 The credential ID of the newly created credential.
 */
@property (nonatomic, readonly, nullable) NSData *credentialId;

/*!
 The credential public key, encoded in COSE key format (RFC 8152).
 */
@property (nonatomic, readonly, nullable) NSData *coseEncodedCredentialPublicKey;

/*
 Not available: instances should be created only by the library.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
