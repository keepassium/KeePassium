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

#import <UIKit/UIKit.h>
#import <CoreNFC/CoreNFC.h>

#import "UIDeviceAdditions.h"
#import "UIDevice+Testing.h"

#import "YubiKitDeviceCapabilities.h"
#import "YubiKitDeviceCapabilities+Testing.h"

@interface YubiKitDeviceCapabilities()

@property (class, nonatomic, readonly) id<YKFUIDeviceProtocol> currentUIDevice;

@end

@implementation YubiKitDeviceCapabilities

+ (BOOL)supportsQRCodeScanning {
#ifdef DEBUG
    // When this is set by UTs.
    if (self.fakeDeviceCapabilities) {
        return [[self.fakeDeviceCapabilities class] supportsQRCodeScanning];
    }
#endif
    
    if (self.currentUIDevice.ykf_deviceModel == YKFDeviceModelSimulator) {
        return NO;
    }
    
    if (@available(iOS 8, *)) {
        return YES;
    }
    return NO;
}

+ (BOOL)supportsNFCScanning {
#ifdef DEBUG
    // When this is set by UTs.
    if (self.fakeDeviceCapabilities) {
        return [[self.fakeDeviceCapabilities class] supportsNFCScanning];
    }
#endif
    
    if (self.currentUIDevice.ykf_deviceModel == YKFDeviceModelSimulator) {
        return NO;
    }
    if (@available(iOS 11, *)) {
        // This check was introduced to avoid some random crashers caused by CoreNFC on devices which are not NFC enabled.
        if ([self deviceIsNFCEnabled]) {
            return NFCNDEFReaderSession.readingAvailable;
        }
        return NO;
    }
    return NO;
}

+ (BOOL)supportsISO7816NFCTags {
#ifdef DEBUG
    // When this is set by UTs.
    if (self.fakeDeviceCapabilities) {
        return [[self.fakeDeviceCapabilities class] supportsISO7816NFCTags];
    }
#endif
    
    if (self.currentUIDevice.ykf_deviceModel == YKFDeviceModelSimulator) {
        return NO;
    }
    if (@available(iOS 13, *)) {
        // This check was introduced to avoid some random crashers caused by CoreNFC on devices which are not NFC enabled.
        if ([self deviceIsNFCEnabled]) {
            return NFCTagReaderSession.readingAvailable;
        }
        return NO;
    }
    return NO;
}

+ (BOOL)supportsMFIAccessoryKey {
#ifdef DEBUG
    // When this is set by UTs.
    if (self.fakeDeviceCapabilities) {
        return [[self.fakeDeviceCapabilities class] supportsMFIAccessoryKey];
    }
#endif

    // Simulator and USB-C type devices
    if (self.currentUIDevice.ykf_deviceModel == YKFDeviceModelSimulator ||
        self.currentUIDevice.ykf_deviceModel == YKFDeviceModelIPadPro3) {
        return NO;
    }
    if (@available(iOS 10, *)) {
        return [self systemSupportsMFIAccessoryKey];
    }
    return NO;
}

#pragma mark - Helpers

+ (id<YKFUIDeviceProtocol>)currentUIDevice {
#ifdef DEBUG
    return testFakeUIDevice ? testFakeUIDevice : UIDevice.currentDevice;
#else
    return UIDevice.currentDevice;
#endif
}

+ (BOOL)deviceIsNFCEnabled {
    static BOOL ykfDeviceCapabilitiesDeviceIsNFCEnabled = YES;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        YKFDeviceModel deviceModel = self.currentUIDevice.ykf_deviceModel;
        ykfDeviceCapabilitiesDeviceIsNFCEnabled =
            deviceModel == YKFDeviceModelIPhone7 || deviceModel == YKFDeviceModelIPhone7Plus ||
            deviceModel == YKFDeviceModelIPhone8 || deviceModel == YKFDeviceModelIPhone8Plus ||
            deviceModel == YKFDeviceModelIPhoneX ||
            deviceModel == YKFDeviceModelIPhoneXS || deviceModel == YKFDeviceModelIPhoneXSMax || deviceModel == YKFDeviceModelIPhoneXR ||
            deviceModel == YKFDeviceModelUnknown; // A newer device which is not in the list yet
    });
    
#ifdef DEBUG
    if (testFakeUIDevice) {
        // When the UTs run, reset to test different configurations.
        onceToken = 0;
    }
#endif
    
    return ykfDeviceCapabilitiesDeviceIsNFCEnabled;
}

+ (BOOL)systemSupportsMFIAccessoryKey {
    static BOOL ykfDeviceCapabilitiesSystemSupportsMFIAccessoryKey = YES;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        // iOS 11.2 Versions
        NSArray *excludedVersions = @[@"11.2", @"11.2.1", @"11.2.2", @"11.2.5"];
        
        NSString *systemVersion = self.currentUIDevice.systemVersion;
        if ([excludedVersions containsObject:systemVersion]) {
            ykfDeviceCapabilitiesSystemSupportsMFIAccessoryKey = NO;
        } else {
            ykfDeviceCapabilitiesSystemSupportsMFIAccessoryKey = YES;
        }
    });
    
#ifdef DEBUG
    if (testFakeUIDevice) {
        // When the UTs run, reset to test different configurations.
        onceToken = 0;
    }
#endif
    
    return ykfDeviceCapabilitiesSystemSupportsMFIAccessoryKey;
}

#pragma mark - Testing additions

#ifdef DEBUG

static id<YKFUIDeviceProtocol> testFakeUIDevice;

+ (void)setFakeUIDevice:(id<YKFUIDeviceProtocol>)fakeUIDevice {
    testFakeUIDevice = fakeUIDevice;
}

+ (id<YKFUIDeviceProtocol>)fakeUIDevice {
    return testFakeUIDevice;
}

static id<YubiKitDeviceCapabilitiesProtocol> testFakeDeviceCapabilities;

+ (void)setFakeDeviceCapabilities:(id<YubiKitDeviceCapabilitiesProtocol>)fakeDeviceCapabilities {
    testFakeDeviceCapabilities = fakeDeviceCapabilities;
}

+ (id<YubiKitDeviceCapabilitiesProtocol>)fakeDeviceCapabilities {
    return testFakeDeviceCapabilities;
}

#endif

@end
