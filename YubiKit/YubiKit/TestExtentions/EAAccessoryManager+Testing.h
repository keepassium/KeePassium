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

@protocol YKFEAAccessoryManagerProtocol<NSObject>

+ (id<YKFEAAccessoryManagerProtocol>)sharedAccessoryManager;

- (void)showBluetoothAccessoryPickerWithNameFilter:(nullable NSPredicate *)predicate completion:(nullable EABluetoothAccessoryPickerCompletion)completion;

- (void)registerForLocalNotifications;
- (void)unregisterForLocalNotifications;

@property (nonatomic, readonly) NSArray<id<YKFEAAccessoryProtocol>> *connectedAccessories;

@end

@interface EAAccessoryManager()<YKFEAAccessoryManagerProtocol>
@end

NS_ASSUME_NONNULL_END
