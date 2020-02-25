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

#import "YKFOTPURIParserProtocol.h"
#import "YKFOTPTextParserProtocol.h"


/*!
 @class YubiKitConfiguration
 
 @abstract
    YubiKitConfiguration allows the host application to configure YubiKit when the default behaviour of
    the library is insufficient for the host application.
 
 NOTE:
    To configure YubiKit using YubiKitConfiguration, access the shared instance from YubiKitManager.
 */
@interface YubiKitConfiguration : NSObject

/*!
 @property customOTPURIParser
 
 @abstract
    Custom parser privided by the host application when the used YubiKeys have a custom
    way of formatting the URI.
 
 NOTE:
    This parser instance is used when the NDEF is configured as URI by the configuration tool. The default
    configuration for the YubiKey is URI. If no changes have been made to the NDEF payload format by configuring
    the YubiKey, this should be left empty and rely on the default parser provided by YubiKit.
 */
@property (class, nonatomic, nullable) id<YKFOTPURIParserProtocol> customOTPURIParser;

/*!
 @property customOTPTextParser
 
 @abstract
    Custom parser privided by the host applicatiopn when the used YubiKeys have a custom way of formatting the Text.
 
 NOTE:
    This parser instance is used when the NDEF is configured as Text by the configuration tool. This is not
    the default configuration for the YubiKey. If no changes have been made to the NDEF payload format by configuring
    the YubiKey, this should be left empty and rely on the default parser provided by YubiKit.
 */
@property (class, nonatomic, nullable) id<YKFOTPTextParserProtocol> customOTPTextParser;

- (nonnull instancetype)init NS_UNAVAILABLE;

@end
