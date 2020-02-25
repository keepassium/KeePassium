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

/*!
 @class YubiKitExternalLocalization
 
 @abstract
    YubiKitExternalLocalization allows the host application to provide localized strings for messages
    shown to the user when YubiKit shows system UIs or build-in UI elements.
 
 NOTE:
    YubiKit already provides some generic non-localized values for the elements shown in the UI. While these are good
    for a prototype phase, for production builds, it is recommended for the host application to provide localized
    values specific for the type of application using the library.
*/
@interface YubiKitExternalLocalization : NSObject

#pragma mark - NFC

/*!
 @property nfcScanAlertMessage
 
 @abstract
    The message shown in the system NFC scan UI. You can customize this by setting a localized value on this property.
    Defaults to a non-localized english string.
 */
@property (class, nonatomic, nonnull) NSString *nfcScanAlertMessage;

#pragma mark - QR code scan

/*!
 @property qrCodeScanHintMessage
 
 @abstract
    The message shown in the UI of the QR code scanner to guide the user to scan the QR Code. You can customize this by
    setting a localized value on this property.
    Defaults to a non-localized english string.
 */
@property (class, nonatomic, nonnull) NSString *qrCodeScanHintMessage;

/*!
 @property qrCodeScanCameraNotAvailableMessage
 
 @abstract
    The message shown in the UI of the QR code scanner when the camera permission was not granted. You can customize this by
    setting a localized value on this property.
    Defaults to a non-localized english string.
 */
@property (class, nonatomic, nonnull) NSString *qrCodeScanCameraNotAvailableMessage;

/*!
 @property qrCodeScanDismissButtonTitle
 
 @abstract
    The title of the Dismiss button in the QR code scan UI. You can customize this by setting a localized value on this property.
    Defaults to a non-localized english string.
 */
@property (class, nonatomic, nonnull) NSString *qrCodeScanDismissButtonTitle;

- (nonnull instancetype)init NS_UNAVAILABLE;

@end
