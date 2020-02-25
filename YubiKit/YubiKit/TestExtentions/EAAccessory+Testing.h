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

NS_ASSUME_NONNULL_BEGIN

@protocol YKFEAAccessoryProtocol<NSObject>

@property(nonatomic, readonly, getter=isConnected) BOOL connected;
@property(nonatomic, readonly) NSUInteger connectionID;

@property(nonatomic, readonly) NSString *manufacturer;
@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) NSString *modelNumber;
@property(nonatomic, readonly) NSString *serialNumber;
@property(nonatomic, readonly) NSString *firmwareRevision;
@property(nonatomic, readonly) NSString *hardwareRevision;
@property(nonatomic, readonly) NSString *dockType;

@property(nonatomic, readonly) NSArray<NSString *> *protocolStrings;

@property(nonatomic, assign, nullable) id<EAAccessoryDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

@interface EAAccessory()<YKFEAAccessoryProtocol>
@end
