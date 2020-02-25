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

#import "YKFKeyU2FSignResponse.h"
#import "YKFAssert.h"

@interface YKFKeyU2FSignResponse()

@property (nonatomic, readwrite) NSString *keyHandle;
@property (nonatomic, readwrite) NSString *clientData;
@property (nonatomic, readwrite) NSData *signature;

@end

@implementation YKFKeyU2FSignResponse

- (instancetype)initWithKeyHandle:(NSString *)keyHandle clientData:(NSString *)clientData signature:(NSData *)signature {
    YKFAssertAbortInit(keyHandle);
    YKFAssertAbortInit(clientData);
    YKFAssertAbortInit(signature);
    
    self = [super init];
    if (self) {
        self.keyHandle = keyHandle;
        self.clientData = clientData;
        self.signature = signature;
    }
    return self;
}

@end
