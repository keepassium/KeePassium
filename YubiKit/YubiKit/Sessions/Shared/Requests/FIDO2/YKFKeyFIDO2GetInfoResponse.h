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
 * @name Options Keys
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Key to fetch clientPin value from YKFKeyFIDO2GetInfoResponse.options
 
 @discussion
    If present and set to true, it indicates that the device is capable of accepting a PIN from the client and
    PIN has been set.
    If present and set to false, it indicates that the device is capable of accepting a PIN from the client and
    PIN has not been set yet.
    If absent, it indicates that the device is not capable of accepting a PIN from the client.
 */
extern NSString* const YKFKeyFIDO2GetInfoResponseOptionClientPin;

/*!
 @abstract
    Key to fetch plat value from YKFKeyFIDO2GetInfoResponse.options
 
 @discussion
    Indicates that the authenticator is attached to the client and therefore can’t be removed and used on another
    client. The value returned by the key will always be false because the key can be removed.
 */
extern NSString* const YKFKeyFIDO2GetInfoResponseOptionPlatformDevice;

/*!
 @abstract
    Key to fetch rk value from YKFKeyFIDO2GetInfoResponse.options
 
 @discussion
    Indicates that the authenticator is capable of storing keys on the device itself and therefore can satisfy the
    Get Assertion request with allowList parameter not specified or empty.
 */
extern NSString* const YKFKeyFIDO2GetInfoResponseOptionResidentKey;

/*!
 @abstract
    Key to fetch up value from YKFKeyFIDO2GetInfoResponse.options
 @discussion
    Indicates that the device is capable of testing user presence.
 */
extern NSString* const YKFKeyFIDO2GetInfoResponseOptionUserPresence;

/*!
 @abstract
    Key to fetch uv value from YKFKeyFIDO2GetInfoResponse.options
 @discussion
    Indicates that the device is capable of verifying the user within itself.
 */
extern NSString* const YKFKeyFIDO2GetInfoResponseOptionUserVerification;

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFKeyFIDO2GetInfoResponse
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    The response to a FIDO2 Get Info request. The result contains the data structures defined in the CTAP2
    authenticatorGetInfo command response.
 */
@interface YKFKeyFIDO2GetInfoResponse: NSObject

/*!
 @abstract
    The list of supported FIDO protocol versions by the authenticator.
 
 @discussion
    This property contains a list of strings as defined by the CTAP2 specifications. Because the key supports
    both FIDO U2F and FIDO2 protocols it will return ["FIDO_2_X", "U2F_V2"] as the result.
 */
@property (nonatomic, readonly) NSArray *versions;

/*!
 @abstract
    The list of supported extensions.
 
 @discussion
    This property contains a list of strings as defined by the CTAP2 specifications. Currently the key supports only
    the "hmac-secret" extension.
 */
@property (nonatomic, readonly, nullable) NSArray *extensions;

/*!
 @abstract
    The claimed AAGUID by the authenticator.
 
 @discussion
    The value should always have 16 bytes in length and encoded the same as MakeCredential AuthenticatorData, as
    specified in WebAuthN.
 */
@property (nonatomic, readonly) NSData *aaguid;

/*!
 @abstract
    The list of supported options by the authenticator.
 
 @discussion
    This dictionary contains the list of keys in the Options Keys section. Based on this information the client can
    deduce what options will be available when requesting new credentials or assertions.
 */
@property (nonatomic, readonly, nullable) NSDictionary *options;

/*!
 @abstract
    Maximum message size supported by the authenticator, in bytes.
 
 @discussion
    The value is 0 when not returned by the authenticator. In CTAP2 this value is optional but the YubiKey will always
    return a value for this property.
 */
@property (nonatomic, readonly) NSUInteger maxMsgSize;

/*!
 @abstract
    The list of PIN Protocol versions supported by the authenticator.
 
 @discussion
    CTAP2 defines only one protocol version, version 1. Because there is only one version for the protocol the
    value of the protocol can be omitted when requesting a new credential or an assertion from the key.
 */
@property (nonatomic, readonly, nullable) NSArray *pinProtocols;

/*
 Not available: the response will be created by the library.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
