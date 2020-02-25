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
#import <UIKit/UIKit.h>

/*!
 @abstract
    Response block used by scanQrCodeWithPresenter:completion: to provide the results of a QR Code scan.
 */
typedef void (^YKFQRCodeResponseBlock)(NSString* _Nullable, NSError* _Nullable);

@protocol YKFQRReaderSessionProtocol<NSObject>

/*!
 @method scanQrCodeWithPresenter:completion:
 
 @param viewController
    The view controller which will be used to present modally the QR Code scanning UI.
 
 @param completion
    The completion block which returns the scanned QR Code value or an error in case of failure.
 
 @abstract
    Async request for scanning a QR Code. After caling this method YubiKit will prompt the user to scan
    the QR Code using a built-in UI presented modally on top of the specified presenter. YubiKit allows to
    customize the default messages shown in the library UI. This can be done by setting localized values
    in YubiKitExternalLocalization.
 
 NOTE:
    Before using this method make sure the project is properly configured to allow the usage of camera. YubiKit provides
    the ability to check if the device supports QR Code scanning by using the shared instance deviceCapabilities
    from YubiKitManager.
 */
- (void)scanQrCodeWithPresenter:(nonnull UIViewController*)viewController completion:(nonnull YKFQRCodeResponseBlock)completion;

/*!
 @method scanQrCodeWithPresenter:completion:
 
 @abstract
    Dismisses the presented QR Code scanning UI, which was presented using scanQrCodeWithPresenter:completion:
 
 NOTE:
    YubiKit will take care of dismissing the UI in case the user pressed on Dismiss button without scanning a QR Code or
    after the scanner detected a QR Code or failed for any reason to do so. This method should be used when the UI needs
    to reset for any reason without user interaction.
 */
- (void)dismissQRCodeScanViewController;

@end

@interface YKFQRReaderSession : NSObject<YKFQRReaderSessionProtocol>
@end
