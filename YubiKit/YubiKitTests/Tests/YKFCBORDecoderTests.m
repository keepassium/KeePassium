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
#import "YKFCBORDecoder.h"

@interface YKFCBORDecoderTests: YKFTestCase

@property (nonatomic) NSArray *testIntegers;
@property (nonatomic) NSArray *testStrings;
@property (nonatomic) NSArray *testLongData;

@end

@implementation YKFCBORDecoderTests

- (void)setUp {
    [super setUp];
    
    // Integers setup

    NSUInteger noIntegers = 5;
    NSMutableArray *integers = [[NSMutableArray alloc] initWithCapacity:noIntegers];
    for (int i = 0; i < noIntegers; ++i) {
        [integers addObject:YKFCBORInteger(i)];
    }
    self.testIntegers = [integers copy];
    
    // Strings setup
    
    NSUInteger noStrings = 5;
    NSMutableArray *strings = [[NSMutableArray alloc] initWithCapacity:noIntegers];
    for (unichar c = 'a'; c < 'a' + noStrings; ++c) {
        [strings addObject:YKFCBORTextString([NSString stringWithCharacters:&c length:1])];
    }
    self.testStrings = [strings copy];
    
    // Long data setup
    
    NSMutableData *testLongData1 = [[NSMutableData alloc] initWithCapacity:23];
    NSMutableData *testLongData2 = [[NSMutableData alloc] initWithCapacity:25];
    NSMutableData *testLongData3 = [[NSMutableData alloc] initWithCapacity:100];
    NSMutableData *testLongData4 = [[NSMutableData alloc] initWithCapacity:255];
    
    for (int i = 0; i <= 255; ++i) {
        UInt8 byte = i;
        if (i < 23) {
            [testLongData1 appendBytes:&byte length:1];
        }
        if (i < 25) {
            [testLongData2 appendBytes:&byte length:1];
        }
        if (i < 100) {
            [testLongData3 appendBytes:&byte length:1];
        }
        [testLongData4 appendBytes:&byte length:1];
    }
    self.testLongData = @[testLongData1, testLongData2, testLongData3, testLongData4];
}

#pragma mark - Integer Tests (MT 0, 1)

- (void)testIntegerDecoding {
    NSArray *testVector = @[@(0), @(1), @(23), @(24), @(100), @(1000), @(1000000), @(1000000000000),
                            @(-1), @(-23), @(-24), @(-100), @(-1000), @(-1000000), @(-1000000000000)];
    
    for (NSNumber *testEntry in testVector) {
        YKFCBORInteger *cborInteger = YKFCBORInteger(testEntry.integerValue);
        
        NSData *encodedInteger = [YKFCBOREncoder encodeInteger:cborInteger];
        
        NSInputStream *inputStream = [NSInputStream inputStreamWithData:encodedInteger];
        [inputStream open];
        id decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
        [inputStream close];
        
        XCTAssert([decodedObject isKindOfClass:YKFCBORInteger.class], @"CBOR - Wrong class decoded when parsing integers.");
        YKFCBORInteger *decodedInteger = (YKFCBORInteger *)decodedObject;
        
        XCTAssertEqual(testEntry.integerValue, decodedInteger.value, @"CBOR - Wrong integer decoded.");
    }
}

#pragma mark - Byte String Tests (MT 2)

- (void)testByteStringDecoding {
    NSArray *testVector = @[[NSData data],
                            [NSData dataWithBytes:(UInt8[]){0x01, 0x02, 0x03, 0x04} length:4],
                            self.testLongData[0],
                            self.testLongData[1],
                            self.testLongData[2],
                            self.testLongData[3]];
    
    for (NSData *testEntry in testVector) {
        YKFCBORByteString *cborByteString = YKFCBORByteString(testEntry);
        
        NSData *encodedByteString = [YKFCBOREncoder encodeByteString:cborByteString];
        
        NSInputStream *inputStream = [NSInputStream inputStreamWithData:encodedByteString];
        [inputStream open];
        id decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
        [inputStream close];
        
        XCTAssert([decodedObject isKindOfClass:YKFCBORByteString.class], @"CBOR - Wrong class decoded when parsing byte strings.");
        YKFCBORByteString *decodedByteString = (YKFCBORByteString *)decodedObject;
        
        XCTAssert([testEntry isEqualToData:decodedByteString.value],  @"CBOR - Wrong byte string decoded.");
    }
}

#pragma mark - Text String Tests (MT 3)

- (void)testTextStringDecoding {
    NSArray *testVector = @[@"", @"a", @"IETF", @"\"\\", @"ü", @"水", @"𐅑"];
    
    for (NSString *testEntry in testVector) {
        YKFCBORTextString *cborTextString = YKFCBORTextString(testEntry);
        NSData *encodedTextString = [YKFCBOREncoder encodeTextString:cborTextString];
        
        NSInputStream *inputStream = [NSInputStream inputStreamWithData:encodedTextString];
        [inputStream open];
        id decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
        [inputStream close];
        
        XCTAssert([decodedObject isKindOfClass:YKFCBORTextString.class], @"CBOR - Wrong class decoded when parsing text strings.");
        YKFCBORTextString *decodedTextString = (YKFCBORTextString *)decodedObject;
        
        XCTAssert([testEntry isEqualToString:decodedTextString.value],  @"CBOR - Wrong text string decoded.");
    }
}

#pragma mark - Array Tests (MT 4)

- (void)testArrayDecoding {
    NSArray *testVector = @[@[],
                            @[self.testIntegers[0],
                              self.testIntegers[1],
                              self.testIntegers[2]],
                            @[self.testIntegers[0],
                              [YKFCBORArray cborArrayWithValue:@[self.testIntegers[0],
                                                                 self.testIntegers[1]]],
                              [YKFCBORArray cborArrayWithValue:@[self.testIntegers[2],
                                                                 self.testIntegers[3]]]],
                            @[self.testStrings[0], [YKFCBORMap cborMapWithValue:
                                                    @{self.testStrings[1]:self.testStrings[2]}]]
                            ];
    
    for (NSArray *testEntry in testVector) {
        YKFCBORArray *cborArray = YKFCBORArray(testEntry);
        NSData *encodedArray = [YKFCBOREncoder encodeArray:cborArray];
        
        NSInputStream *inputStream = [NSInputStream inputStreamWithData:encodedArray];
        [inputStream open];
        id decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
        [inputStream close];
        
        XCTAssert([decodedObject isKindOfClass:YKFCBORArray.class], @"CBOR - Wrong class decoded when parsing array.");
        YKFCBORArray *decodedArray = (YKFCBORArray *)decodedObject;
        
        XCTAssert([testEntry isEqualToArray:decodedArray.value],  @"CBOR - Wrong array decoded.");
    }
}

#pragma mark - Map Tests (MT 5)

- (void)testMapDecoding {
    NSArray *testVector = @[@{},
                            @{self.testIntegers[0]: self.testIntegers[1],
                              self.testIntegers[2]: self.testIntegers[3]},
                            @{self.testStrings[0]: self.testIntegers[0],
                              self.testStrings[1]:[YKFCBORArray cborArrayWithValue:
                                                   @[self.testIntegers[1],
                                                     self.testIntegers[2]]]},
                            @{self.testStrings[0]: self.testIntegers[0],
                              self.testStrings[1]:[YKFCBORArray cborArrayWithValue:
                                                   @[self.testIntegers[1],
                                                     self.testIntegers[2]]]}
                            ];
    
    for (NSDictionary *testEntry in testVector) {
        YKFCBORMap *cborMap = YKFCBORMap(testEntry);
        NSData *encodedMap = [YKFCBOREncoder encodeMap:cborMap];
        
        NSInputStream *inputStream = [NSInputStream inputStreamWithData:encodedMap];
        [inputStream open];
        id decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
        [inputStream close];
        
        XCTAssert([decodedObject isKindOfClass:YKFCBORMap.class], @"CBOR - Wrong class decoded when parsing map.");
        YKFCBORMap *decodedMap = (YKFCBORMap *)decodedObject;
        
        XCTAssert([testEntry isEqualToDictionary:decodedMap.value],  @"CBOR - Wrong map decoded.");
    }
}

#pragma mark - Bool Tests

- (void)testBooleanDecoding {
    NSData *trueEncoded = [YKFCBOREncoder encodeBool: YKFCBORBool(YES)];
    NSData *falseEncoded = [YKFCBOREncoder encodeBool: YKFCBORBool(NO)];
    
    NSMutableData *inputData = [[NSMutableData alloc] initWithCapacity:trueEncoded.length + falseEncoded.length];
    [inputData appendData:trueEncoded];
    [inputData appendData:falseEncoded];

    NSInputStream *inputStream = [NSInputStream inputStreamWithData:inputData];
    [inputStream open];
    
    id decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
    XCTAssert([decodedObject isKindOfClass:YKFCBORBool.class], @"CBOR - Wrong class decoded when parsing bool.");
    XCTAssert(((YKFCBORBool *)decodedObject).value == YES, @"CBOR - Wrong bool value decoded.");

    decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
    XCTAssert([decodedObject isKindOfClass:YKFCBORBool.class], @"CBOR - Wrong class decoded when parsing bool.");
    XCTAssert(((YKFCBORBool *)decodedObject).value == NO, @"CBOR - Wrong bool value decoded.");
    
    [inputStream close];
}

#pragma mark - Mixed Tests

- (void)testMixedInputMap {
    NSDictionary *testInput = @{self.testIntegers[0]: self.testStrings[0],
                                self.testIntegers[1]: self.testStrings[1],
                                self.testIntegers[2]: self.testStrings[2],
                                self.testIntegers[4]:
                                    [YKFCBORMap cborMapWithValue:
                                     @{self.testStrings[0]: self.testIntegers[0],
                                       self.testStrings[1]: self.testIntegers[1],
                                       self.testStrings[2]: [YKFCBORArray cborArrayWithValue:
                                                             @[self.testIntegers[0],
                                                               self.testIntegers[1],
                                                               self.testStrings[0],
                                                               self.testStrings[1]]
                                                             ]
                                       }]
                                };
    NSData *encodedMap = [YKFCBOREncoder encodeMap:YKFCBORMap(testInput)];
    
    NSInputStream *inputStream = [NSInputStream inputStreamWithData:encodedMap];
    [inputStream open];
    id decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
    [inputStream close];

    XCTAssert([decodedObject isKindOfClass:YKFCBORMap.class], @"CBOR - Wrong class decoded when parsing map.");
    YKFCBORMap *decodedMap = (YKFCBORMap *)decodedObject;
    
    XCTAssert([testInput isEqualToDictionary:decodedMap.value],  @"CBOR - Wrong map decoded.");
}

- (void)testMixedInputArray {
    NSArray *testInput = @[self.testIntegers[0],
                           self.testStrings[0],
                           self.testIntegers[1],
                           self.testStrings[1],
                           self.testIntegers[2],
                           self.testStrings[2],
                           self.testIntegers[3],
                           [YKFCBORMap cborMapWithValue:
                            @{self.testStrings[0]: self.testIntegers[0],
                              self.testStrings[1]: self.testIntegers[1],
                              self.testStrings[2]:[YKFCBORArray cborArrayWithValue:
                                                   @[self.testIntegers[0],
                                                     self.testIntegers[1],
                                                     self.testStrings[0],
                                                     self.testStrings[1]]
                                                   ]
                              }]
                           ];
    NSData *encodedArray = [YKFCBOREncoder encodeArray:YKFCBORArray(testInput)];
    
    NSInputStream *inputStream = [NSInputStream inputStreamWithData:encodedArray];
    [inputStream open];
    id decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
    [inputStream close];
    
    XCTAssert([decodedObject isKindOfClass:YKFCBORArray.class], @"CBOR - Wrong class decoded when parsing array.");
    YKFCBORArray *decodedArray = (YKFCBORArray *)decodedObject;
    
    XCTAssert([testInput isEqualToArray:decodedArray.value],  @"CBOR - Wrong array decoded.");
}

- (void)testMixedInputUngroupped {
    NSDictionary *objectInput1 = @{self.testIntegers[0]: self.testStrings[0],
                                   self.testIntegers[1]: self.testStrings[1],
                                   self.testIntegers[2]: self.testStrings[2],
                                   self.testIntegers[3]:
                                       [YKFCBORMap cborMapWithValue:
                                        @{self.testStrings[0]: self.testIntegers[0],
                                          self.testStrings[1]: self.testIntegers[1],
                                          self.testStrings[2]: [YKFCBORArray cborArrayWithValue:
                                                                @[self.testIntegers[0],
                                                                  self.testIntegers[1],
                                                                  self.testStrings[0],
                                                                  self.testStrings[1]]
                                                                ]
                                          }]
                                   };
    
    NSDictionary *objectInput2 = @{self.testIntegers[0]: self.testStrings[0],
                                   self.testIntegers[1]: self.testStrings[1],
                                   self.testIntegers[2]: self.testStrings[2]};
    
    NSData *encodedMap1 = [YKFCBOREncoder encodeMap:YKFCBORMap(objectInput1)];
    NSData *encodedMap2 = [YKFCBOREncoder encodeMap:YKFCBORMap(objectInput2)];
    
    NSMutableData *inputData = [[NSMutableData alloc] initWithCapacity:encodedMap1.length + encodedMap2.length];
    [inputData appendData:encodedMap1];
    [inputData appendData:encodedMap2];
    
    NSInputStream *inputStream = [NSInputStream inputStreamWithData:inputData];
    [inputStream open];

    // Check first map
    id decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
    XCTAssert([decodedObject isKindOfClass:YKFCBORMap.class], @"CBOR - Wrong class decoded when parsing map.");
    YKFCBORMap *decodedMap = (YKFCBORMap *)decodedObject;
    XCTAssert([objectInput1 isEqualToDictionary:decodedMap.value],  @"CBOR - Wrong map decoded.");

    // Check second map
    decodedObject = [YKFCBORDecoder decodeObjectFrom:inputStream];
    XCTAssert([decodedObject isKindOfClass:YKFCBORMap.class], @"CBOR - Wrong class decoded when parsing map.");
    decodedMap = (YKFCBORMap *)decodedObject;
    XCTAssert([objectInput2 isEqualToDictionary:decodedMap.value],  @"CBOR - Wrong map decoded.");
    
    [inputStream close];
}

@end
