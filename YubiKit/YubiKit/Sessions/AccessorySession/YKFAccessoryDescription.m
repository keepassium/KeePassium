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

#import "YKFAccessoryDescription.h"
#import "YKFAssert.h"
#import "YKFAccessoryDescription+Private.h"

@interface YKFAccessoryDescription()

@property(nonatomic, readwrite) NSString *manufacturer;
@property(nonatomic, readwrite) NSString *name;
@property(nonatomic, readwrite) NSString *modelNumber;
@property(nonatomic, readwrite) NSString *serialNumber;
@property(nonatomic, readwrite) NSString *firmwareRevision;
@property(nonatomic, readwrite) NSString *hardwareRevision;

@end

@implementation YKFAccessoryDescription

- (instancetype)initWithAccessory:(id<YKFEAAccessoryProtocol>)accessory {
    YKFAssertAbortInit(accessory);
    
    self = [super init];
    if (self) {
        NSAssert(accessory.manufacturer, @"Manufacturer not provided by the accessory.");
        self.manufacturer = accessory.manufacturer;
        YKFAssertAbortInit(self.manufacturer);
        
        NSAssert(accessory.name, @"Name not provided by the accessory.");
        self.name = accessory.name;
        YKFAssertAbortInit(self.name);
        
        NSAssert(accessory.modelNumber, @"Model number not provided by the accessory.");
        self.modelNumber = accessory.modelNumber;
        YKFAssertAbortInit(self.modelNumber);
        
        NSAssert(accessory.firmwareRevision, @"Firmware revision not provided by the accessory.");
        self.firmwareRevision = accessory.firmwareRevision;
        YKFAssertAbortInit(self.firmwareRevision);
        
        // The production firmware should always have only 3 number chars.
        if (self.firmwareRevision.length == 3 && [self.firmwareRevision integerValue]) {
            NSMutableString *updatedFirmware = [[NSMutableString alloc] initWithString:self.firmwareRevision];
            [updatedFirmware insertString:@"." atIndex:2];
            [updatedFirmware insertString:@"." atIndex:1];
            self.firmwareRevision = [updatedFirmware copy];
        }
        
        NSAssert(accessory.hardwareRevision, @"Hardware revision not provided by the accessory.");
        self.hardwareRevision = accessory.hardwareRevision;
        YKFAssertAbortInit(self.hardwareRevision);
        
        NSAssert(accessory.serialNumber, @"Serial number not provided by the accessory.");
        self.serialNumber = accessory.serialNumber;
        YKFAssertAbortInit(self.serialNumber);
    }
    
    return self;
}

@end
