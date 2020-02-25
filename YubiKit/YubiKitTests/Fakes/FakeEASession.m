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

#import "FakeEASession.h"

@interface FakeEASession()

@property (nonatomic, readwrite) id<YKFEAAccessoryProtocol> accessory;
@property (nonatomic, readwrite) NSString *protocolString;
@property (nonatomic, readwrite) NSInputStream *inputStream;
@property (nonatomic, readwrite) NSOutputStream *outputStream;

@end

@implementation FakeEASession

- (instancetype)initWithInputData:(NSData *)inputData accessory:(id<YKFEAAccessoryProtocol>)accessory protocol:(NSString *)protocol {
    self = [super init];
    if (self) {
        self.inputStream = [[NSInputStream alloc] initWithData:inputData];
        self.outputStream = [[NSOutputStream alloc] initToMemory];
        
        self.accessory = accessory;
        self.protocolString = protocol;
    }
    return self;
}

- (NSData *)outputStreamData {
    return [[self.outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] copy];
}

@end
