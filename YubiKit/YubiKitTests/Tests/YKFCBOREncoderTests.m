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

#import <XCTest/XCTest.h>
#import "YKFTestCase.h"
#import "YKFCBOREncoder.h"

@interface YKFCBOREncoderTests: YKFTestCase
@end

@implementation YKFCBOREncoderTests

#pragma mark - Integer Tests (MT 0, 1)

- (void)testPositiveIntegerEncoding {
    NSArray *testVectors =
        @[@[@(0), [NSData dataWithBytes:(UInt8[]){0x00} length:1]],
          @[@(1), [NSData dataWithBytes:(UInt8[]){0x01} length:1]],
          @[@(10), [NSData dataWithBytes:(UInt8[]){0x0A} length:1]],
          @[@(23), [NSData dataWithBytes:(UInt8[]){0x17} length:1]],
          @[@(24), [NSData dataWithBytes:(UInt8[]){0x18, 0x18} length:2]],
          @[@(25), [NSData dataWithBytes:(UInt8[]){0x18, 0x19} length:2]],
          @[@(100), [NSData dataWithBytes:(UInt8[]){0x18, 0x64} length:2]],
          @[@(1000), [NSData dataWithBytes:(UInt8[]){0x19, 0x03, 0xE8} length:3]],
          @[@(1000000), [NSData dataWithBytes:(UInt8[]){0x1A, 0x00, 0x0F, 0x42, 0x40} length:5]],
          @[@(1000000000000), [NSData dataWithBytes:(UInt8[]){0x1B, 0x00, 0x00, 0x00, 0xE8, 0xD4, 0xA5, 0x10, 0x00} length:9]]
          ];
    
    for (NSArray *testEntry in testVectors) {
        NSInteger integer = ((NSNumber *)testEntry[0]).integerValue;
        YKFCBORInteger *cborInteger = YKFCBORInteger(integer);
        
        NSData *encodedInteger = [YKFCBOREncoder encodeInteger:cborInteger];
        NSData *expectedEncodedData = (NSData *)testEntry[1];
        
        XCTAssert([encodedInteger isEqualToData:expectedEncodedData], @"Data encoding does not match for positive integer (%ld).", (long)integer);
    }
}

- (void)testNegativeIntegerEncoding {
    NSArray *testVectors =
        @[@[@(-1), [NSData dataWithBytes:(UInt8[]){0x20} length:1]],
          @[@(-10), [NSData dataWithBytes:(UInt8[]){0x29} length:1]],
          @[@(-100), [NSData dataWithBytes:(UInt8[]){0x38, 0x63} length:2]],
          @[@(-1000), [NSData dataWithBytes:(UInt8[]){0x39, 0x03, 0xE7} length:3]]
          ];
    
    for (NSArray *testEntry in testVectors) {
        NSInteger integer = ((NSNumber *)testEntry[0]).integerValue;
        YKFCBORInteger *cborInteger = YKFCBORInteger(integer);
        
        NSData *encodedInteger = [YKFCBOREncoder encodeInteger:cborInteger];
        NSData *expectedEncodedData = (NSData *)testEntry[1];
        
        XCTAssert([encodedInteger isEqualToData:expectedEncodedData], @"Data encoding does not match for negative integer (%ld).", (long)integer);
    }
}

#pragma mark - Byte String Tests (MT 2)

- (void)testByteStringEncoding {
    NSArray *testVectors =
        @[@[[NSData data], [NSData dataWithBytes:(UInt8[]){0x40} length:1]],
          @[[NSData dataWithBytes:(UInt8[]){0x01, 0x02, 0x03, 0x04} length:4], [NSData dataWithBytes:(UInt8[]){0x44, 0x01, 0x02, 0x03, 0x04} length:5]]
          ];

    for (NSArray *testEntry in testVectors) {
        NSData *data = ((NSData *)testEntry[0]);
        YKFCBORByteString *cborByteString = YKFCBORByteString(data);
        
        NSData *encodedData = [YKFCBOREncoder encodeByteString:cborByteString];
        NSData *expectedEncodedData = (NSData *)testEntry[1];
        
        XCTAssert([encodedData isEqualToData:expectedEncodedData], @"Data encoding does not match for byte string (%@).", encodedData.description);
    }
}

#pragma mark - Text String Tests (MT 3)

- (void)testTextStringEncoding {
    NSArray *testVectors =
        @[@[@"", [NSData dataWithBytes:(UInt8[]){0x60} length:1]],
          @[@"a", [NSData dataWithBytes:(UInt8[]){0x61, 0x61} length:2]],
          @[@"IETF", [NSData dataWithBytes:(UInt8[]){0x64, 0x49, 0x45, 0x54, 0x46} length:5]],
          @[@"\"\\", [NSData dataWithBytes:(UInt8[]){0x62, 0x22, 0x5C} length:3]],
          @[@"ü", [NSData dataWithBytes:(UInt8[]){0x62, 0xC3, 0xBC} length:3]],
          @[@"水", [NSData dataWithBytes:(UInt8[]){0x63, 0xE6, 0xB0, 0xB4} length:4]],
          @[@"𐅑", [NSData dataWithBytes:(UInt8[]){0x64, 0xF0, 0x90, 0x85, 0x91} length:5]]
          ];

    for (NSArray *testEntry in testVectors) {
        NSString *string = ((NSString *)testEntry[0]);
        YKFCBORTextString *cborTextString = YKFCBORTextString(string);
        
        NSData *encodedData = [YKFCBOREncoder encodeTextString:cborTextString];
        NSData *expectedEncodedData = (NSData *)testEntry[1];
        
        XCTAssert([encodedData isEqualToData:expectedEncodedData], @"Data encoding does not match for text string (%@).", string);
    }    
}

#pragma mark - Array Tests (MT 4)

- (void)testArrayEncoding {
    YKFCBORInteger *int1 = YKFCBORInteger(1);
    YKFCBORInteger *int2 = YKFCBORInteger(2);
    YKFCBORInteger *int3 = YKFCBORInteger(3);
    YKFCBORInteger *int4 = YKFCBORInteger(4);
    YKFCBORInteger *int5 = YKFCBORInteger(5);
    
    YKFCBORTextString *stringA = YKFCBORTextString(@"a");
    YKFCBORTextString *stringB = YKFCBORTextString(@"b");
    YKFCBORTextString *stringC = YKFCBORTextString(@"c");
    
    NSArray *testVectors =
        @[@[@[], [NSData dataWithBytes:(UInt8[]){0x80} length:1]],
          @[@[int1, int2, int3],
            [NSData dataWithBytes:(UInt8[]){0x83, 0x01, 0x02, 0x03} length:4]],
          @[@[int1, [YKFCBORArray cborArrayWithValue:@[int2, int3]], [YKFCBORArray cborArrayWithValue:@[int4, int5]]],
            [NSData dataWithBytes:(UInt8[]){0x83, 0x01, 0x82, 0x02, 0x03, 0x82, 0x04, 0x05} length:8]],
          @[@[stringA, [YKFCBORMap cborMapWithValue:@{stringB: stringC}]],
            [NSData dataWithBytes:(UInt8[]){0x82, 0x61, 0x61, 0xA1, 0x61, 0x62, 0x61, 0x63} length:8]]
          ];
    
    for (NSArray *testEntry in testVectors) {
        NSArray *array = ((NSArray *)testEntry[0]);
        YKFCBORArray *cborArray = YKFCBORArray(array);
        
        NSData *encodedData = [YKFCBOREncoder encodeArray:cborArray];
        NSData *expectedEncodedData = (NSData *)testEntry[1];
        
        XCTAssert([encodedData isEqualToData:expectedEncodedData], @"Data encoding does not match for array.");
    }
}

#pragma mark - Map Tests (MT 5)

- (void)testMapEncoding {
    YKFCBORInteger *int1 = YKFCBORInteger(1);
    YKFCBORInteger *int2 = YKFCBORInteger(2);
    YKFCBORInteger *int3 = YKFCBORInteger(3);
    YKFCBORInteger *int4 = YKFCBORInteger(4);
    
    YKFCBORTextString *stringA = YKFCBORTextString(@"a");
    YKFCBORTextString *stringB = YKFCBORTextString(@"b");
    
    NSArray *testVectors =
        @[@[@{}, [NSData dataWithBytes:(UInt8[]){0xA0} length:1]],
          @[@{int1: int2, int3: int4},
            [NSData dataWithBytes:(UInt8[]){0xA2, 0x01, 0x02, 0x03, 0x04} length:5]],
          @[@{stringA: int1, stringB: [YKFCBORArray cborArrayWithValue:@[int2, int3]]},
            [NSData dataWithBytes:(UInt8[]){0xA2, 0x61, 0x61, 0x01, 0x61, 0x62, 0x82, 0x02, 0x03} length:9]],
          @[@{stringA: int1, stringB: [YKFCBORArray cborArrayWithValue:@[int2, int3]]},
            [NSData dataWithBytes:(UInt8[]){0xA2, 0x61, 0x61, 0x01, 0x61, 0x62, 0x82, 0x02, 0x03} length:9]]
          ];

    for (NSArray *testEntry in testVectors) {
        NSDictionary *dictionary = ((NSDictionary *)testEntry[0]);
        YKFCBORMap *cborMap = YKFCBORMap(dictionary);
        
        NSData *encodedData = [YKFCBOREncoder encodeMap:cborMap];
        NSData *expectedEncodedData = (NSData *)testEntry[1];
        
        XCTAssert([encodedData isEqualToData:expectedEncodedData], @"Data encoding does not match for map.");
    }
}

- (void)testMapKeysSorting {
    YKFCBORInteger *int1 = YKFCBORInteger(1);
    YKFCBORInteger *int2 = YKFCBORInteger(2);
    YKFCBORInteger *int3 = YKFCBORInteger(3);
    YKFCBORInteger *int4 = YKFCBORInteger(4);
    
    YKFCBORTextString *stringA = YKFCBORTextString(@"b");
    YKFCBORTextString *stringB = YKFCBORTextString(@"aa");
    YKFCBORTextString *stringC = YKFCBORTextString(@"bb");
    YKFCBORTextString *stringD = YKFCBORTextString(@"aaa");
    
    NSDictionary *testMap = @{stringD: int1, stringC: int2, stringB: int3, stringA: int4}; // reversed order keys
    YKFCBORMap *cborMap = YKFCBORMap(testMap);
    
    NSData *encodedData = [YKFCBOREncoder encodeMap:cborMap];
    
    UInt8 bytes[] = {0xa4, 0x61, 0x62, 0x04, 0x62, 0x61, 0x61, 0x03, 0x62, 0x62, 0x62, 0x02, 0x63, 0x61, 0x61, 0x61, 0x01};
    NSData *expectedData = [NSData dataWithBytes:bytes length:17];
    
    XCTAssert([encodedData isEqualToData:expectedData], @"The encoded data does not match the content and the required CTAP2 order.");
}

#pragma mark - Bool Tests

- (void)testBoolEncoding {
    NSData *trueEncoded = [YKFCBOREncoder encodeBool: YKFCBORBool(YES)];
    NSData *falseEncoded = [YKFCBOREncoder encodeBool: YKFCBORBool(NO)];
    
    XCTAssert([trueEncoded isEqualToData:[NSData dataWithBytes:(UInt8[]){0xF5} length:1]]);
    XCTAssert([falseEncoded isEqualToData:[NSData dataWithBytes:(UInt8[]){0xF4} length:1]]);
}

@end
