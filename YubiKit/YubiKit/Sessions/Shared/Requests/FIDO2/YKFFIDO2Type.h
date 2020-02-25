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

NS_ASSUME_NONNULL_BEGIN

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFFIDO2PublicKeyCredentialRpEntity
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFFIDO2PublicKeyCredentialRpEntity
 
 @abstract
    Data structure to represent a Relying Party in FIDO2/CTAP2, used in authenticator requests like Make Credential.
 
 @discussion
    To optimize the communication with the authenticator, it's recommended to use short values for names and icon URLs.
 */
@interface YKFFIDO2PublicKeyCredentialRpEntity: NSObject

/// A required unique ID of the RP, usually a domain name (e.g. yubico.com).
@property (nonatomic) NSString *rpId;

/// An optional human readable name for the RP (e.g. Yubico).
@property (nonatomic, nullable) NSString *rpName;

/// An optional URI to the RP icon (e.g. https://www.yubico.com/rpicon.png).
@property (nonatomic, nullable) NSString *rpIcon;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFFIDO2PublicKeyCredentialUserEntity
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFFIDO2PublicKeyCredentialUserEntity
 
 @abstract
    Data structure to represent a User in FIDO2/CTAP2, used in authenticator requests like Make Credential.
 
 @discussion
    To optimize the communication with the authenticator, it's recommended to use short values for names and icon URLs.
 */
@interface YKFFIDO2PublicKeyCredentialUserEntity: NSObject

/// A required unique User ID, used by the RP to indentify the user in the RP systems.
@property (nonatomic) NSData *userId;

/// An optional username (usually an account name) used by the RP to identify the user (e.g. john.smith@yubico.com).
@property (nonatomic, nullable) NSString *userName;

/// An optional display name of the user (e.g. John Smith).
@property (nonatomic, nullable) NSString *userDisplayName;

/// An optional URI to the User Icon (e.g. https://www.yubico.com/johnsmith.png).
@property (nonatomic, nullable) NSString *userIcon;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFFIDO2PublicKeyCredentialType
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFFIDO2PublicKeyCredentialType
 
 @abstract
    Data structure to represent a public credential type in FIDO2/CTAP2, used in authenticator requests like Get Assertion.
 */
@interface YKFFIDO2PublicKeyCredentialType: NSObject

/// In FIDO2/CTAP2 the public credential is a public key, so the value of this name should be "public-key".
@property (nonatomic) NSString *name;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFFIDO2PublicKeyCredentialParam
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    ECDSA (Elliptic Curve Digital Signature Algorithm) using P-256 and SHA-256
 
 @discussion
    The authenticator will generate an ECC-256 (curve P-256) key pair for the credential and use the private key to
    sign a SHA256 (32 bytes of data) when requesting signatures from the authenticator.
 */
static const NSInteger YKFFIDO2PublicKeyAlgorithmES256 = -7;

/*!
 @abstract
    EdDSA (Edwards-curve Digital Signature Algorithm), using the Ed25519 curve.
 
 @discussion
    The authenticator will generate an Ed25519 key pair for the credential and use the private key to sign a SHA256 (32 bytes
    of data) when requesting signatures from the authenticator.
 */
static const NSInteger YKFFIDO2PublicKeyAlgorithmEdDSA = -8;

/*!
 @class YKFFIDO2PublicKeyCredentialParam
 
 @abstract
    Data structure to represent the desired public key parameters when creating a FIDO2 credential.
 */
@interface YKFFIDO2PublicKeyCredentialParam: NSObject

/// The type of algorithm to use for the credential (YKFFIDO2PublicKeyAlgorithmES256 or YKFFIDO2PublicKeyAlgorithmEdDSA).
@property (nonatomic) NSInteger alg;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFFIDO2AuthenticatorTransport
 * ---------------------------------------------------------------------------------------------------------------------
 */

/// Constant for USB transport name.
extern NSString* const YKFFIDO2AuthenticatorTransportUSB;

/// Constant for NFC transport name.
extern NSString* const YKFFIDO2AuthenticatorTransportNFC;

/// Constant for BLE transport name.
extern NSString* const YKFFIDO2AuthenticatorTransportBLE;

/*!
 @class YKFFIDO2AuthenticatorTransport
 
 @abstract
    Data structure to represent how the application communicates with the authenticator (over USB, NFC or BLE).
 */
@interface YKFFIDO2AuthenticatorTransport: NSObject

/*!
 The name of the transport:
 YKFFIDO2AuthenticatorTransportUSB, YKFFIDO2AuthenticatorTransportNFC or YKFFIDO2AuthenticatorTransportBLE
 */
@property (nonatomic) NSString *name;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFFIDO2PublicKeyCredentialDescriptor
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*
 @class YKFFIDO2PublicKeyCredentialDescriptor
 
 @abstract
    Data structure to represent a FIDO2 credential, used in requests like Make Credential or Get Assertion.
 */
@interface YKFFIDO2PublicKeyCredentialDescriptor: NSObject

/// The unique ID of the credential, usually generated by the authenticator when a credential is created.
@property (nonatomic) NSData *credentialId;

/// The type of the credential.
@property (nonatomic) YKFFIDO2PublicKeyCredentialType *credentialType;

/// An optional list of YKFFIDO2AuthenticatorTransport objects.
@property (nonatomic, nullable) NSArray *credentialTransports;

@end

NS_ASSUME_NONNULL_END
