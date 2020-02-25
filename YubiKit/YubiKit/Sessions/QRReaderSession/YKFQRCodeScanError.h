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
 @constant
    YKFQRCodeScanErrorDomain
 @abstract
    Domain for errors from the QR code scanning.
 */
extern NSString* _Nonnull const YKFQRCodeScanErrorDomain;

/*!
 @class
    YKFQRCodeScanError
 @abstract
    Error from QR Code scanning.
 */
@interface YKFQRCodeScanError : NSError

- (nonnull instancetype)init NS_UNAVAILABLE;

@end

/*!
 @constant
    YKFQRCodeScanErrorNoCameraAvailableCode
 @abstract
    When the camera device is not available.
 */
extern int const YKFQRCodeScanErrorNoCameraAvailableCode;

/*!
 @constant
    YKFQRCodeScanErrorUnableToCreateCaptureDeviceInputCode
 @abstract
    When the library is not able to create a device input to attach to the capture device (camera).
 */
extern int const YKFQRCodeScanErrorUnableToCreateCaptureDeviceInputCode;

/*!
 @constant
    YKFQRCodeScanErrorUnableToAddDeviceInputCode
 @abstract
    When the library is not able to attach the capture input to the capture device (camera).
 */
extern int const YKFQRCodeScanErrorUnableToAddDeviceInputCode;

/*!
 @constant
    YKFQRCodeScanErrorUnableToAddQrDetectorCode
 @abstract
    When the library is not able to detect QR Codes.
 */
extern int const YKFQRCodeScanErrorUnableToAddQrDetectorCode;

/*!
 @constant
    YKFQRCodeScanErrorNoDataAvailableCode
 @abstract
    When the library did read a QR Code but data could not be extracted from it.
 */
extern int const YKFQRCodeScanErrorNoDataAvailableCode;
