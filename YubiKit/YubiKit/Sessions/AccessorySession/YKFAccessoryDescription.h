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
 @class YKFAccessoryDescription
 
 @abstract
    Provides a list of properties describing the connected key.
 */
@interface YKFAccessoryDescription : NSObject

/*!
 @property manufacturer
 
 @abstract
    The manufacturer of the key. YubiKit is designed to connect only to Yubico keys. The value of this property
    should be always Yubico.
 */
@property(nonatomic, readonly) NSString *manufacturer;

/*!
 @property name
 
 @abstract
    The name of the key (e.g. YubiKey 5Ci, etc.).
 */
@property(nonatomic, readonly) NSString *name;

/*!
 @property modelNumber
 
 @abstract
    The model of the key. This property gives more details about the specific subtype of key (e.g. Neo, etc.).
 */
@property(nonatomic, readonly) NSString *modelNumber;

/*!
 @property serialNumber
 
 @abstract
    The unique serial number of the key.
 */
@property(nonatomic, readonly) NSString *serialNumber;

/*!
 @property firmwareRevision
 
 @abstract
    The firmware version of the key (e.g. 1.0.0, etc.)
 */
@property(nonatomic, readonly) NSString *firmwareRevision;

/*!
 @property hardwareRevision
 
 @abstract
    The hardware revision of the key (e.g. r1, r2, etc.)
 */
@property(nonatomic, readonly) NSString *hardwareRevision;

/*
 Not available: access the instance provided by YKFAccessorySession.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
