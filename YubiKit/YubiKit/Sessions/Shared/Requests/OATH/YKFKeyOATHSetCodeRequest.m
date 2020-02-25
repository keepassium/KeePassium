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

#import "YKFKeyOATHSetCodeRequest.h"
#import "YKFAssert.h"

@interface YKFKeyOATHSetCodeRequest()

@property (nonatomic, readwrite) NSString *password;

@end

@implementation YKFKeyOATHSetCodeRequest

- (instancetype)initWithPassword:(nonnull NSString *)password {
    YKFAssertAbortInit(password);
    
    self = [super init];
    if (self) {
        self.password = password;
        // Note: APDU is not set yet. It will be set after the salt is received as a result of a select application request.
    }
    return self;
}

@end
