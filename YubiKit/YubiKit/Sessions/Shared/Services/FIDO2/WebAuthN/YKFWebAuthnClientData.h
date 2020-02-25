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
 * @name YKFWebAuthnClientData Types
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 The list of supported WebAuthN operations.
 */
typedef NS_ENUM(NSUInteger, YKFWebAuthnClientDataType) {
    
    /// When the Client Data is used for creating a new credential.
    YKFWebAuthnClientDataTypeCreate,
    
    /// When the Client Data is used to get an assertion from an existing credential.
    YKFWebAuthnClientDataTypeGet
};

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFWebAuthnClientData
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFWebAuthnClientData
 
 @abstract
    A representation of the WebAuthN Client Data used with the FIDO2 APIs.
 */
@interface YKFWebAuthnClientData: NSObject

/*!
 @abstract
    The operation type the Client Data will be used for. This property has the value YKFWebAuthnClientDataTypeCreate
    when creating new credentials and YKFWebAuthnClientDataTypeGet when getting an assertion from an existing credential.
 */
@property (nonatomic, readonly) YKFWebAuthnClientDataType type;

/*!
 @abstract
    The challenge received from the WebAuthN Relying Party.
 */
@property (nonatomic, readonly) NSData *challenge;

/*!
 @abstract
    This member contains the fully qualified origin of the requester, as provided to the authenticator by the client.
 */
@property (nonatomic, readonly) NSString *origin;

/*!
 @abstract
    This is a derived property which returns the clientDataJson as defined by WebAuthN:
    https://www.w3.org/TR/webauthn/#sec-client-data
 */
@property (nonatomic, nullable, readonly) NSData *jsonData;

/*!
 @abstract
    This is a derived property which returns the SHA-256 of the clientDataJson.
 */
@property (nonatomic, nullable, readonly) NSData *clientDataHash;

/*!
 @method initWithType:challenge:origin:
 
 @abstract
    The designated initializer for this type. All the parameters are required to properly
    initialise the Client Data.
 
 @param type
    The operation type.
 @param challenge
    The challenge to use for the operation.
 @param origin
    The origin of the Relying Party.
 */
- (nullable instancetype)initWithType:(YKFWebAuthnClientDataType)type challenge:(NSData *)challenge origin:(NSString *)origin NS_DESIGNATED_INITIALIZER;

/*
 Not available: use initWithType:challenge:origin:
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
