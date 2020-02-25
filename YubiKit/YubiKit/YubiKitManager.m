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

#import <ExternalAccessory/ExternalAccessory.h>

#import "YubiKitManager.h"
#import "YKFAccessorySessionConfiguration.h"

#import "YKFNFCOTPService+Private.h"
#import "YKFAccessorySession+Private.h"

@interface YubiKitManager()

@property (nonatomic, readwrite) id<YKFNFCSessionProtocol> nfcSession NS_AVAILABLE_IOS(11.0);
@property (nonatomic, readwrite) id<YKFQRReaderSessionProtocol> qrReaderSession;
@property (nonatomic, readwrite) id<YKFAccessorySessionProtocol> accessorySession;

@end

@implementation YubiKitManager

static id<YubiKitManagerProtocol> sharedInstance;

+ (id<YubiKitManagerProtocol>)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[YubiKitManager alloc] initOnce];
    });
    return sharedInstance;
}

- (instancetype)initOnce {
    self = [super init];
    if (self) {
        if (@available(iOS 11, *)) {
            self.nfcSession = [[YKFNFCSession alloc] init];
        }
        self.qrReaderSession = [[YKFQRReaderSession alloc] init];
        
        YKFAccessorySessionConfiguration *configuration = [[YKFAccessorySessionConfiguration alloc] init];
        EAAccessoryManager *accessoryManager = [EAAccessoryManager sharedAccessoryManager];
        
        self.accessorySession = [[YKFAccessorySession alloc] initWithAccessoryManager:accessoryManager configuration:configuration];
    }
    return self;
}

@end
