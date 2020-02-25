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

@protocol YKFOTPTokenProtocol;

/*!
 @abstract
    Response block used by requestOTPToken: to provide the results of a OTP NFC scan.
 */
typedef void (^YKFOTPResponseBlock)(id<YKFOTPTokenProtocol> _Nullable, NSError* _Nullable);


API_AVAILABLE(ios(11.0))
@protocol YKFNFCOTPServiceProtocol<NSObject>

/*!
 @method requestOTPToken:
 
 @param completion
    The completion block which returns the response from the OTP token request using NFC.
 
 @abstract
    Async call for requesting a OTP token from a YubiKey supporting NFC. After caling
    this method YubiKit will prompt the user to scan the YubiKey using the native NFC scanning UI.
    To provide an additional message to guide the user or to provide a reason for the scan, YubiKit
    allows to customize the default message shown in the system UI. This can be done by setting
    a localized value in YubiKitExternalLocalization.
 
 NOTE:
    Before using this method make sure the project is properly configured to allow NFC reading. Using the NFC reader
    requires iOS 11 and iPhone 7 or above. For more details check CoreNFC requirements. YubiKit provides the ability
    to check if the device supports NFC reading by using the shared instance deviceCapabilities from YubiKitManager.
 */
- (void)requestOTPToken:(nonnull YKFOTPResponseBlock)completion;

@end

API_AVAILABLE(ios(11.0))
@interface YKFNFCOTPService : NSObject<YKFNFCOTPServiceProtocol>

/*
 Not available: use the shared single instance from YubiKitManager.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
