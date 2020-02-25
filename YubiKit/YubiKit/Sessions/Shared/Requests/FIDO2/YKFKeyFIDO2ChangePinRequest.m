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

#import "YKFKeyFIDO2ChangePinRequest.h"
#import "YKFAssert.h"

@interface YKFKeyFIDO2ChangePinRequest()

@property (nonatomic, readwrite) NSString *pinOld;
@property (nonatomic, readwrite) NSString *pinNew;

@end

@implementation YKFKeyFIDO2ChangePinRequest

- (nullable instancetype)initWithNewPin:(NSString *)newPin oldPin:(NSString *)oldPin {
    self = [super init];
    if (self) {
        YKFAssertAbortInit(newPin);
        YKFAssertAbortInit(oldPin);
        
        self.pinOld = oldPin;
        self.pinNew = newPin;
    }
    return self;
}

@end
