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

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFOTPToken Types
 * ---------------------------------------------------------------------------------------------------------------------
 */

typedef NS_ENUM(NSUInteger, YKFOTPTokenType) {
    /*!
     @constant  YKFOTPTokenTypeYubicoOTP
                The token is of type YubicoOTP.
     */
    YKFOTPTokenTypeYubicoOTP,
    
    /*!
     @constant  YKFOTPTokenTypeHOTP
                The token is of type HOTP.
     */
    YKFOTPTokenTypeHOTP,
    
    /*!
     @constant  YKFOTPTokenTypeUnknown
                The token type was not properly initialized.
     */
    YKFOTPTokenTypeUnknown
};

typedef NS_ENUM(NSUInteger, YKFOTPMetadataType) {
    /*!
     @constant  YKFOTPMetadataTypeURI
                The token was provided with URI metadata.
     */
    YKFOTPMetadataTypeURI,

    /*!
     @constant  YKFOTPMetadataTypeText
                The token was provided with Text metadata.
     */
    YKFOTPMetadataTypeText,
    
    /*!
     @constant  YKFOTPMetadataTypeUnknown
                The token metadata type was not properly initialized.
     */
    YKFOTPMetadataTypeUnknown
};

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFOTPTokenProtocol
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @protocol YKFOTPTokenProtocol
 
 @abstract
    Provides the the interface for an OTP token.
 */
@protocol YKFOTPTokenProtocol<NSObject>

/*!
 @property type
 
 @abstract
    The type of token received from the YubiKey.
 */
@property (nonatomic) YKFOTPTokenType type;

/*!
 @property metadataType
 
 @abstract
    The type of the metadata received with the OTP token from the YubiKey.
 */
@property (nonatomic) YKFOTPMetadataType metadataType;

/*!
 @property value
 
 @abstract
    The OTP extracted from the payload received from the YubiKey.
 */
@property (nonatomic, nonnull) NSString *value;

/*!
 @property uri
 
 @abstract
    If the YubiKey was configured to provide an URI when providing the OTP token,
    this property contains the URI.
 
 NOTE:
    The URI is the default configuration for YubiKeys.
 */
@property (nonatomic, nullable) NSString *uri;

/*!
 @property text
 
 @abstract
    If the YubiKey was configured to provide a text when providing the OTP token,
    this property contains the text.
 */
@property (nonatomic, nullable) NSString *text;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFOTPToken
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFOTPToken
 
 @abstract
    Default implementation for YKFOTPTokenProtocol.
 */
@interface YKFOTPToken : NSObject<YKFOTPTokenProtocol>
@end
