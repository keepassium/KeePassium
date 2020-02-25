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

#import <XCTest/XCTest.h>

#import "YKFTestCase.h"
#import "YKFAccessorySessionConfiguration.h"
#import "FakeEAAccessory.h"
#import "EAAccessory+Testing.h"

@interface YKFAccessorySessionConfigurationTests: YKFTestCase

@property (nonatomic) YKFAccessorySessionConfiguration *sessionConfiguration;
@property (nonatomic) FakeEAAccessory *accessory;

@end

@implementation YKFAccessorySessionConfigurationTests

- (void)setUp {
    [super setUp];
    self.sessionConfiguration = [[YKFAccessorySessionConfiguration alloc] init];
    self.accessory = [[FakeEAAccessory alloc] init];
}

#pragma mark -  Protocol Tests

- (void)test_WhenAccessoryProtocolIsYLP_AccessoryIsAllowed {
    self.accessory.manufacturer = @"Yubico";
    self.accessory.protocolStrings = @[@"com.yubico.ylp"];
    
    BOOL allowsAccessory = [self.sessionConfiguration allowsAccessory:self.accessory];
    XCTAssertTrue(allowsAccessory, @"Does not allow accessory with YLP protocol.");
}

- (void)test_WhenAccessoryProtocolIsNotRecognised_AccessoryIsNotAllowed {
    self.accessory.manufacturer = @"Yubico";
    self.accessory.protocolStrings = @[@"Unknown"];
    
    BOOL allowsAccessory = [self.sessionConfiguration allowsAccessory:self.accessory];
    XCTAssertFalse(allowsAccessory, @"Aallows accessory which has unknown protocol.");
}

#pragma mark -  Manufacturer Tests

- (void)test_WhenAccessoryManufacturerIsYubico_AccessoryIsAllowed {
    self.accessory.manufacturer = @"Yubico";
    self.accessory.protocolStrings = @[@"com.yubico.ylp"];
    
    BOOL allowsAccessory = [self.sessionConfiguration allowsAccessory:self.accessory];
    XCTAssertTrue(allowsAccessory, @"Does not allow accessory which is manufactured by Yubico.");
}

- (void)test_WhenAccessoryManufacturerIsNotYubico_AccessoryIsNotAllowed {
    self.accessory.manufacturer = @"Unknown";
    self.accessory.protocolStrings = @[@"com.yubico.ylp"];
    
    BOOL allowsAccessory = [self.sessionConfiguration allowsAccessory:self.accessory];
    XCTAssertFalse(allowsAccessory, @"Allows accessory which is not manufactured by Yubico.");
}

#pragma mark -  Misc Tests

- (void)test_WhenAccessoryIsYubiKey_AccessoryIsAllowed {
    self.accessory.manufacturer = @"Yubico";
    self.accessory.protocolStrings = @[@"com.yubico.ylp"];
    
    BOOL allowsAccessory = [self.sessionConfiguration allowsAccessory:self.accessory];
    XCTAssertTrue(allowsAccessory, @"Does not allow accessory.");    
}

@end
