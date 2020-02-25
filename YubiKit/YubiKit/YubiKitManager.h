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

#import "YKFNFCSession.h"
#import "YKFQRReaderSession.h"
#import "YKFAccessorySession.h"

/*!
 @protocol YubiKitManagerProtocol
 
 @abstract
    Provides the main access point interface for YubiKit.
 */
@protocol YubiKitManagerProtocol

/*!
 @property nfcReaderSession
 
 @abstract
    Returns the shared instance of YKFNFCSession to interact with the NFC reader.
 */
@property (nonatomic, readonly, nonnull) id<YKFNFCSessionProtocol> nfcSession NS_AVAILABLE_IOS(11.0);

/*!
 @property qrReaderSession
 
 @abstract
    Returns the shared instance of YKFQRReaderSession to interact with the QR Code reader.
 */
@property (nonatomic, readonly, nonnull) id<YKFQRReaderSessionProtocol> qrReaderSession;

/*!
 @property accessorySession
 
 @abstract
    Returns the shared instance of YKFAccessorySession to interact with a MFi accessory YubiKey.
 */
@property (nonatomic, readonly, nonnull) id<YKFAccessorySessionProtocol> accessorySession;

@end


/*!
 @class YubiKitManager
 
 @abstract
    Provides the main access point for YubiKit.
 */
@interface YubiKitManager : NSObject<YubiKitManagerProtocol>

/*!
 @property shared
 
 @abstract
    YubiKitManager is a singleton and should be accessed only by using the shared instance provided by this property.
 */
@property (class, nonatomic, readonly, nonnull) id<YubiKitManagerProtocol> shared;

/*
 Not available: use the shared property from YubiKitManager to retreive the shared single instance.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
