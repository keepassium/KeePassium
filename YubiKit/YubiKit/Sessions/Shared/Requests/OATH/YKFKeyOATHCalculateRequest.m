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

#import "YKFKeyOATHCalculateRequest.h"
#import "YKFKeyOATHCalculateRequest+Private.h"
#import "YKFOATHCalculateAPDU.h"
#import "YKFAssert.h"
#import "YKFKeyOATHRequest+Private.h"

@interface YKFKeyOATHCalculateRequest()

@property (nonatomic, readwrite) YKFOATHCredential *credential;

@end

@implementation YKFKeyOATHCalculateRequest

- (instancetype)initWithCredential:(nonnull YKFOATHCredential*)credential {
    return [self initWithCredential:credential timestamp:[NSDate date]];
}

- (instancetype)initWithCredential:(nonnull YKFOATHCredential*)credential timestamp: (NSDate*) timestamp {
    YKFAssertAbortInit(credential);
    
    if (credential.type == YKFOATHCredentialTypeTOTP) {
        YKFAssertAbortInit(credential.period > 0);
    }
    
    self = [super init];
    if (self) {
        self.credential = credential;
        self.timestamp = timestamp;
        self.apdu = [[YKFOATHCalculateAPDU alloc] initWithRequest:self timestamp:self.timestamp];
    }
    return self;
}

@end
