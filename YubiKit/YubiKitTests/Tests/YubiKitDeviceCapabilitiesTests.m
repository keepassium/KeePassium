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

#import "YubiKitDeviceCapabilities.h"
#import "YubiKitDeviceCapabilities+Testing.h"

#import "YKFTestCase.h"
#import "FakeUIDevice.h"

@interface YubiKitDeviceCapabilitiesTests: YKFTestCase
@end

@implementation YubiKitDeviceCapabilitiesTests

- (void)tearDown {
    [super tearDown];
    YubiKitDeviceCapabilities.fakeUIDevice = nil;
}

#pragma mark - NFC

- (void)test_WhenRunningInSimulator_NFCIsNotSupported {
    FakeUIDevice *fakeDevice = [[FakeUIDevice alloc] init];
    
    YubiKitDeviceCapabilities.fakeUIDevice = fakeDevice;
    fakeDevice.ykf_deviceModel = YKFDeviceModelSimulator;
    
    XCTAssert(!YubiKitDeviceCapabilities.supportsNFCScanning, @"The device capabilities do not block the simulator for NFC");
}

- (void)test_WhenRunningOnOldDevices_NFCIsNotSupported {
    FakeUIDevice *fakeDevice = [[FakeUIDevice alloc] init];
    
    YubiKitDeviceCapabilities.fakeUIDevice = fakeDevice;
    
    fakeDevice.ykf_deviceModel = YKFDeviceModelIPhone5;
    XCTAssert(!YubiKitDeviceCapabilities.supportsNFCScanning, @"The device capabilities do not block old devices for NFC");
    
    fakeDevice.ykf_deviceModel = YKFDeviceModelIPhone6;
    XCTAssert(!YubiKitDeviceCapabilities.supportsNFCScanning, @"The device capabilities do not block old devices for NFC");
    
    fakeDevice.ykf_deviceModel = YKFDeviceModelIPhone6S;
    XCTAssert(!YubiKitDeviceCapabilities.supportsNFCScanning, @"The device capabilities do not block old devices for NFC");
}

#pragma mark - MFI Accessory

- (void)test_WhenRunningUnsupportedOSVersions_MFIAccessoryKeyIsNotSupported {
    FakeUIDevice *fakeDevice = [[FakeUIDevice alloc] init];
    
    YubiKitDeviceCapabilities.fakeUIDevice = fakeDevice;
    fakeDevice.ykf_deviceModel = YKFDeviceModelIPhone6;
    
    NSArray *unsupportedVersions = @[@"11.2", @"11.2.1", @"11.2.2", @"11.2.5"];
    for (NSString *version in unsupportedVersions) {
        fakeDevice.systemVersion = version;
        XCTAssert(!YubiKitDeviceCapabilities.supportsMFIAccessoryKey, @"The device capabilities do not block unsupported OS version: %@.", version);
    }
}

- (void)test_WhenRunningSupportedOSVersions_MFIAccessoryKeyIsSupported {
    FakeUIDevice *fakeDevice = [[FakeUIDevice alloc] init];
    
    YubiKitDeviceCapabilities.fakeUIDevice = fakeDevice;
    fakeDevice.ykf_deviceModel = YKFDeviceModelIPhone6;
    
    NSArray *unsupportedVersions = @[@"10.0", @"11.0", @"11.1", @"11.3", @"12.0", @"12.2", @"12.3"];
    for (NSString *version in unsupportedVersions) {
        fakeDevice.systemVersion = version;
        XCTAssert(YubiKitDeviceCapabilities.supportsMFIAccessoryKey, @"The device capabilities do not allow supported OS version: %@.", version);
    }
}

- (void)test_WhenRunningInSimulator_MFIAccessoryKeyIsNotSupported {
    FakeUIDevice *fakeDevice = [[FakeUIDevice alloc] init];
    
    YubiKitDeviceCapabilities.fakeUIDevice = fakeDevice;
    fakeDevice.ykf_deviceModel = YKFDeviceModelSimulator;
    
    XCTAssert(!YubiKitDeviceCapabilities.supportsMFIAccessoryKey, @"The device capabilities do not block the simulator.");
}

- (void)test_WhenRunningOnUSBCDevices_MFIAccessoryKeyIsNotSupported {
    FakeUIDevice *fakeDevice = [[FakeUIDevice alloc] init];
    
    YubiKitDeviceCapabilities.fakeUIDevice = fakeDevice;
    fakeDevice.ykf_deviceModel = YKFDeviceModelIPadPro3;
    
    XCTAssert(!YubiKitDeviceCapabilities.supportsMFIAccessoryKey, @"The device capabilities do not block USB-C devices.");
}

@end
