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

#import "YKFKeyOATHPutRequest.h"
#import "YKFOATHPutAPDU.h"
#import "YKFAssert.h"
#import "YKFKeyOATHRequest+Private.h"

@interface YKFKeyOATHPutRequest()

@property (nonatomic, readwrite) YKFOATHCredential *credential;

@end

@implementation YKFKeyOATHPutRequest

- (instancetype)initWithCredential:(YKFOATHCredential *)credential {
    YKFAssertAbortInit(credential);
    
    self = [super init];
    if (self) {
        YKFAssertAbortInit(credential.label.length);
        YKFAssertAbortInit(credential.secret.length);
        YKFAssertAbortInit(credential.type != YKFOATHCredentialTypeUnknown);
        YKFAssertAbortInit(credential.algorithm != YKFOATHCredentialAlgorithmUnknown);
                
        self.credential = credential;
        self.apdu = [[YKFOATHPutAPDU alloc] initWithRequest:self];
    }
    return self;
}

@end
