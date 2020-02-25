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
#import "YKFAccessoryDescription.h"
#import "YKFAccessoryDescription+Private.h"
#import "FakeEAAccessory.h"

@interface YKFAccessoryDescriptionTests: YKFTestCase
@end

@implementation YKFAccessoryDescriptionTests

- (void)test_WhenKeyDescriptionIsInitializedWithAccessory_TheDataIsCorrectlyCopiedOver {
    FakeEAAccessory *accessory = [[FakeEAAccessory alloc] init];
    
    accessory.manufacturer = @"Yubico";
    accessory.name = @"YubiKey";
    accessory.modelNumber = @"5Ci";
    accessory.serialNumber = @"AFF3BBEE";
    accessory.firmwareRevision = @"1.0.0";
    accessory.hardwareRevision = @"r1";

    YKFAccessoryDescription *accessoryDescription = [[YKFAccessoryDescription alloc] initWithAccessory:accessory];
    
    XCTAssertEqual(accessoryDescription.manufacturer, accessory.manufacturer);
    XCTAssertEqual(accessoryDescription.name, accessory.name);
    XCTAssertEqual(accessoryDescription.modelNumber, accessory.modelNumber);
    XCTAssertEqual(accessoryDescription.serialNumber, accessory.serialNumber);
    XCTAssertEqual(accessoryDescription.firmwareRevision, accessory.firmwareRevision);
    XCTAssertEqual(accessoryDescription.hardwareRevision, accessory.hardwareRevision);
}

- (void)test_WhenFirmwareVersionIsConcatenated_FirmwareVersionIsParsed {
    FakeEAAccessory *accessory = [[FakeEAAccessory alloc] init];
    
    accessory.manufacturer = @"Yubico";
    accessory.name = @"YubiKey";
    accessory.modelNumber = @"5Ci";
    accessory.serialNumber = @"AFF3BBEE";
    accessory.firmwareRevision = @"100";
    accessory.hardwareRevision = @"r1";
    
    YKFAccessoryDescription *accessoryDescription = [[YKFAccessoryDescription alloc] initWithAccessory:accessory];
    
    XCTAssert([accessoryDescription.firmwareRevision isEqualToString: @"1.0.0"]);
}

@end
