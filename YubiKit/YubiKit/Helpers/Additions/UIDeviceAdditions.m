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

#import <sys/utsname.h>
#import "UIDeviceAdditions.h"

@implementation UIDevice(YKFDeviceAdditions)

static YKFDeviceModel ykf_deviceModelInternal = YKFDeviceModelUnknown;

- (YKFDeviceModel)ykf_setupDeviceModel {
#if TARGET_IPHONE_SIMULATOR
    return YKFDeviceModelSimulator;
#else
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    // iPhone models
    
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone3,1", @"iPhone3,2", @"iPhone3,3"]]) {
        return YKFDeviceModelIPhone4;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone4,1", @"iPhone4,2", @"iPhone4,3"]]) {
        return YKFDeviceModelIPhone4S;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone5,1", @"iPhone5,2"]]) {
        return YKFDeviceModelIPhone5;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone5,3", @"iPhone5,4"]]) {
        return YKFDeviceModelIPhone5C;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone6,1", @"iPhone6,2"]]) {
        return YKFDeviceModelIPhone5S;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone7,2"]]) {
        return YKFDeviceModelIPhone6;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone7,1"]]) {
        return YKFDeviceModelIPhone6Plus;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone8,1"]]) {
        return YKFDeviceModelIPhone6S;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone8,2"]]) {
        return YKFDeviceModelIPhone6SPlus;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone8,4"]]) {
        return YKFDeviceModelIPhoneSE;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone9,1", @"iPhone9,3"]]) {
        return YKFDeviceModelIPhone7;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone9,2", @"iPhone9,4"]]) {
        return YKFDeviceModelIPhone7Plus;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone10,1", @"iPhone10,4"]]) {
        return YKFDeviceModelIPhone8;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone10,2", @"iPhone10,5"]]) {
        return YKFDeviceModelIPhone8Plus;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone10,3", @"iPhone10,6"]]) {
        return YKFDeviceModelIPhoneX;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone11,2"]]) {
        return YKFDeviceModelIPhoneXS;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone11,4", @"iPhone11,6"]]) {
        return YKFDeviceModelIPhoneXSMax;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPhone11,8"]]) {
        return YKFDeviceModelIPhoneXR;
    }

    // iPad models

    if ([self ykf_deviceName:deviceName isInList:@[@"iPad1,1"]]) {
        return YKFDeviceModelIPad1;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad2,1", @"iPad2,2", @"iPad2,3", @"iPad2,4"]]) {
        return YKFDeviceModelIPad2;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad3,1", @"iPad3,2", @"iPad3,3"]]) {
        return YKFDeviceModelIPad3;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad3,4", @"iPad3,5", @"iPad3,6"]]) {
        return YKFDeviceModelIPad4;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad4,1", @"iPad4,2", @"iPad4,3"]]) {
        return YKFDeviceModelIPadAir;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad5,3", @"iPad5,4"]]) {
        return YKFDeviceModelIPadAir2;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad2,5", @"iPad2,6", @"iPad2,7"]]) {
        return YKFDeviceModelIPadMini;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad4,4", @"iPad4,5", @"iPad4,6"]]) {
        return YKFDeviceModelIPadMini2;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad4,7", @"iPad4,8", @"iPad4,9"]]) {
        return YKFDeviceModelIPadMini3;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad5,1", @"iPad5,2"]]) {
        return YKFDeviceModelIPadMini4;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad6,3", @"iPad6,4", @"iPad6,7", @"iPad6,8"]]) {
        return YKFDeviceModelIPadPro;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad6,11", @"iPad6,12"]]) {
        return YKFDeviceModelIPad2017;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad7,1", @"iPad7,2", @"iPad7,3", @"iPad7,4"]]) {
        return YKFDeviceModelIPadPro2;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad7,5", @"iPad7,6"]]) {
        return YKFDeviceModelIPad6;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPad8,1", @"iPad8,2", @"iPad8,3", @"iPad8,4", @"iPad8,5", @"iPad8,6", @"iPad8,7", @"iPad8,8"]]) {
        return YKFDeviceModelIPadPro3;
    }
    
    // iPod models

    if ([self ykf_deviceName:deviceName isInList:@[@"iPod1,1"]]) {
        return YKFDeviceModelIPodTouch1;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPod2,1"]]) {
        return YKFDeviceModelIPodTouch2;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPod3,1"]]) {
        return YKFDeviceModelIPodTouch3;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPod4,1"]]) {
        return YKFDeviceModelIPodTouch4;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPod5,1"]]) {
        return YKFDeviceModelIPodTouch5;
    }
    if ([self ykf_deviceName:deviceName isInList:@[@"iPod7,1"]]) {
        return YKFDeviceModelIPodTouch6;
    }

    // Unknown device
    
    return YKFDeviceModelUnknown;
#endif
}

- (BOOL)ykf_deviceName:(NSString *)deviceName isInList:(NSArray *)deviceList {
    return [deviceList containsObject:deviceName];
}

- (YKFDeviceModel)ykf_deviceModel {
    // The device type does not change at runtime so set it up once.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ykf_deviceModelInternal = [self ykf_setupDeviceModel];
    });
    return ykf_deviceModelInternal;
}

@end

