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

#import "YKFKeyU2FRegisterResponse.h"
#import "YKFAssert.h"

@interface YKFKeyU2FRegisterResponse()

@property (nonatomic, readwrite) NSString *clientData;
@property (nonatomic, readwrite) NSData *registrationData;

@end

@implementation YKFKeyU2FRegisterResponse

- (instancetype)initWithClientData:(NSString *)clientData registrationData:(NSData *)registrationData {
    YKFAssertAbortInit(clientData);
    YKFAssertAbortInit(registrationData);
    
    self = [super init];
    if (self) {
        self.clientData = clientData;
        self.registrationData = registrationData;
    }
    return self;
}

@end
