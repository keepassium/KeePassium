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

#import "YKFAccessorySessionConfiguration.h"
#import "YKFAssert.h"

// Protocols
static NSString* const YKFAccessorySessionConfigurationYLPProtocolName = @"com.yubico.ylp";

// Manufactures
static NSString* const YKFAccessorySessionConfigurationYubicoManufacturesName = @"Yubico";

@interface YKFAccessorySessionConfiguration()

@property (nonatomic) NSArray *allowedProtocols;
@property (nonatomic) NSArray *allowedManufactures;

@end

@implementation YKFAccessorySessionConfiguration

- (instancetype)init {
    self = [super init];
    if (self) {
        self.allowedProtocols = @[YKFAccessorySessionConfigurationYLPProtocolName];
        self.allowedManufactures = @[YKFAccessorySessionConfigurationYubicoManufacturesName];
    }
    return self;
}

#pragma mark - YKFAccessorySessionConfigurationDelegate

- (BOOL)allowsAccessory:(id<YKFEAAccessoryProtocol>)accessory {
    YKFParameterAssertReturnValue(accessory, NO);
    return  [self allowsProtocols:accessory.protocolStrings] && [self allowsManufacturer:accessory.manufacturer];
}

- (NSString *)keyProtocolForAccessory:(id<YKFEAAccessoryProtocol>)accessory {
    YKFParameterAssertReturnValue(accessory, nil);
    
    NSArray *protocols = accessory.protocolStrings;
    
    if (![self allowsProtocols:protocols]) {
        return nil;
    }
    
    // Return the first known protocol because the key allows only one session.
    for (NSString *protocol in protocols) {
        if ([self.allowedProtocols containsObject:protocol]) {
            return protocol;
        }
    }
    
    return nil;
}

#pragma mark - Helpers

- (BOOL)allowsProtocols:(NSArray *)protocols {
    for (NSString *protocol in protocols) {
        if ([self.allowedProtocols containsObject:protocol]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)allowsManufacturer:(NSString *)manufacturer {
    return [self.allowedManufactures containsObject:manufacturer];
}

@end
