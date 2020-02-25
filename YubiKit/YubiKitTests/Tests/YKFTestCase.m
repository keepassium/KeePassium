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

#import "YKFTestCase.h"

@implementation YKFTestCase

- (void)waitForTimeInterval:(NSTimeInterval)timeInterval {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Delay expectation"];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:timeInterval];
    NSAssert(result == XCTWaiterResultTimedOut, @"Delay expectation failure");
}

#pragma mark - Data Construction

- (NSData *)dataWithBytes:(NSArray *)bytes {
    NSMutableData *mutableData = [[NSMutableData alloc] initWithCapacity:bytes.count];
    for (NSNumber *byte in bytes) {
        UInt8 byteValue = byte.unsignedCharValue;
        [mutableData appendBytes:&byteValue length:1];
    }
    return [mutableData copy];
}

@end
