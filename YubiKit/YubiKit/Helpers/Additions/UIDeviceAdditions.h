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

typedef NS_ENUM(NSUInteger, YKFDeviceModel) {
    
    YKFDeviceModelUnknown,
    YKFDeviceModelSimulator,
    
    // iPhone models
    
    YKFDeviceModelIPhone4,
    YKFDeviceModelIPhone4S,
    YKFDeviceModelIPhone5,
    YKFDeviceModelIPhone5C,
    YKFDeviceModelIPhone5S,
    YKFDeviceModelIPhone6,
    YKFDeviceModelIPhone6Plus,
    YKFDeviceModelIPhone6S,
    YKFDeviceModelIPhone6SPlus,
    YKFDeviceModelIPhoneSE,
    YKFDeviceModelIPhone7,
    YKFDeviceModelIPhone7Plus,
    YKFDeviceModelIPhone8,
    YKFDeviceModelIPhone8Plus,
    YKFDeviceModelIPhoneX,
    YKFDeviceModelIPhoneXS,
    YKFDeviceModelIPhoneXSMax,
    YKFDeviceModelIPhoneXR,
    
    // iPad models
    
    YKFDeviceModelIPad1,
    YKFDeviceModelIPad2,
    YKFDeviceModelIPadMini,
    YKFDeviceModelIPad3,
    YKFDeviceModelIPad4,
    YKFDeviceModelIPadAir,
    YKFDeviceModelIPadMini2,
    YKFDeviceModelIPadAir2,
    YKFDeviceModelIPadMini3,
    YKFDeviceModelIPadMini4,
    YKFDeviceModelIPadPro,
    YKFDeviceModelIPad2017,
    YKFDeviceModelIPadPro2,
    YKFDeviceModelIPad6,
    YKFDeviceModelIPadPro3,
    
    // iPod models
    
    YKFDeviceModelIPodTouch1,
    YKFDeviceModelIPodTouch2,
    YKFDeviceModelIPodTouch3,
    YKFDeviceModelIPodTouch4,
    YKFDeviceModelIPodTouch5,
    YKFDeviceModelIPodTouch6
};

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice(YKFDeviceType)

@property (nonatomic, assign, readonly) YKFDeviceModel ykf_deviceModel;

@end

NS_ASSUME_NONNULL_END
