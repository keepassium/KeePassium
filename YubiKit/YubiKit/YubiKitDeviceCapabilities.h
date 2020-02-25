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

/*!
 @protocol YubiKitDeviceCapabilitiesProtocol
 
 @abstract
    Interface for device capabilities required by YubiKit to run.
 
 NOTE:
    It is important for the host application to check these capabilities before setting up any UI or actions
    which involve NFC and/or QR Code scanning.
 */
@protocol YubiKitDeviceCapabilitiesProtocol<NSObject>

/*!
 @property supportsQRCodeScanning
 
 @abstract
    Returns YES if the device can use a camera to scan a QR Code. Generally speaking this should not return
    NO on any real device because all modern iOS devices have cameras and run recent versions of the OS.
 */ 
@property (class, nonatomic, assign, readonly) BOOL supportsQRCodeScanning;

/*!
 @property supportsNFCScanning
 
 @abstract
    Returns YES if the device can access the NFC device to scan NDEF tags.
 */
@property (class, nonatomic, assign, readonly) BOOL supportsNFCScanning;

/*!
 @property supportsISO7816NFCTags
 
 @abstract
    Returns YES if the device can communicate with ISO 7816 NFC compatible tags.
 */
@property (class, nonatomic, assign, readonly) BOOL supportsISO7816NFCTags;


/*!
 @property supportsMFIAccessoryKey
 
 @abstract
 Returns YES if the device and the OS version can interact with the MFI accessory YubiKeys.
 */
@property (class, nonatomic, assign, readonly) BOOL supportsMFIAccessoryKey;

@end

/*!
 @class YubiKitDeviceCapabilities
 
 @abstract
    Default implementation for YKFDeviceCapabilitiesProtocol.
*/
@interface YubiKitDeviceCapabilities : NSObject<YubiKitDeviceCapabilitiesProtocol>
@end

NS_ASSUME_NONNULL_END
