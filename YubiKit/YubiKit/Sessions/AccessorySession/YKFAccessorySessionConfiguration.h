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
#import <ExternalAccessory/ExternalAccessory.h>
#import "EAAccessory+Testing.h"

NS_ASSUME_NONNULL_BEGIN

@protocol YKFAccessorySessionConfigurationProtocol <NSObject>

/// Returns YES if the accessory is a YubiKey.
- (BOOL)allowsAccessory:(nonnull id<YKFEAAccessoryProtocol>)accessory;

/// Returns the known session protocol found in the protocols array received from an accessory.
- (nullable NSString *)keyProtocolForAccessory:(nonnull id<YKFEAAccessoryProtocol>)accessory;

@end

@interface YKFAccessorySessionConfiguration : NSObject<YKFAccessorySessionConfigurationProtocol>
@end

NS_ASSUME_NONNULL_END
