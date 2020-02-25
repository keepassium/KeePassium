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

#import "YKFCBORDecoder.h"
#import "YKFCBORTag.h"
#import "YKFAssert.h"

@interface NSInputStream(YKFCBORDecoder)

- (UInt8)dequeueHead:(BOOL *)error;
- (NSData *)dequeueBytes:(NSUInteger)numberOfBytes;

@end

@implementation YKFCBORDecoder

+ (nullable id)decodeObjectFrom:(NSInputStream *)inputStream {
    YKFAssertReturnValue(inputStream, @"CBOR - Decoding input stream is nil.", nil);
    YKFAssertReturnValue(inputStream.streamStatus == NSStreamStatusOpen, @"CBOR - Decoding input stream not opened.", nil);
    YKFAssertReturnValue(inputStream.hasBytesAvailable, @"CBOR - Cannot decode from empty input stream.", nil);

    BOOL headReadingError = NO;
    UInt8 head = [inputStream dequeueHead:&headReadingError];
    YKFAssertReturnValue(!headReadingError, @"CBOR - Decoding input stream error.", nil);

    // MT 0,1: Integer (Positive || Negative)
    if (head >= 0x00 && head <= 0x3B) {
        return [self decodeIntegerFromInputStream:inputStream header:head];
    }
    // MT 2: Byte String
    if (head >= 0x40 && head <= 0x5B) {
        return [self decodeByteStringFromInputStream:inputStream header:head];
    }
    // MT 3: Text String
    if (head >= 0x60 && head <= 0x7B) {
        return [self decodeTextStringFromInputStream:inputStream header:head];
    }
    // MT 4: Array
    if (head >= 0x80 && head <= 0x9B) {
        return [self decodeArrayFromInputStream:inputStream header:head];
    }
    // MT 5: Map
    if (head >= 0xA0 && head <= 0xBB) {
        return [self decodeMapFromInputStream:inputStream header:head];
    }
    // Bool
    if (head == 0xF4 || head == 0xF5) {
        return [self decodeBoolFromInputStream:inputStream header:head];
    }
    
    return nil;
}

#pragma mark - Helpers

+ (YKFCBORInteger *)decodeIntegerFromInputStream:(NSInputStream *)inputStream header:(UInt8)header {
    NSData *integerData = nil;
    
    if ((header >= 0x00 && header <= 0x17) || (header >= 0x20 && header <= 0x37)) {
        integerData = [self readObjectFromInputStream:inputStream header:header size:0];
    }
    else if (header == 0x18 || header == 0x38) {
        integerData = [self readObjectFromInputStream:inputStream header:header size:1];
    }
    else if (header == 0x19 || header == 0x39) {
        integerData = [self readObjectFromInputStream:inputStream header:header size:2];
    }
    else if (header == 0x1A || header == 0x3A) {
        integerData = [self readObjectFromInputStream:inputStream header:header size:4];
    }
    else if (header == 0x1B || header == 0x3B) {
        integerData = [self readObjectFromInputStream:inputStream header:header size:8];
    }
    YKFAssertReturnValue(integerData, @"CBOR - Decoding input stream error. Could not read Integer.", nil);
    
    return [self decodeInteger:integerData];
}

+ (YKFCBORByteString *)decodeByteStringFromInputStream:(NSInputStream *)inputStream header:(UInt8)header {
    UInt8 integerHeader = header & ~YKFCBORByteStringTagMask; // Remove MT mask from the number of elements.
    YKFCBORInteger *numberOfBytes = [self decodeIntegerFromInputStream:inputStream header:integerHeader];
    
    NSData *byteStringData = [self readObjectFromInputStream:inputStream header:header size:numberOfBytes.value];
    YKFAssertReturnValue(byteStringData, @"CBOR - Decoding input stream error. Could not read Byte String.", nil);
    
    return [self decodeByteString:byteStringData];
}

+ (YKFCBORTextString *)decodeTextStringFromInputStream:(NSInputStream *)inputStream header:(UInt8)header {
    UInt8 integerHeader = header & ~YKFCBORTextStringTagMask; // Remove MT mask from the number of elements.
    YKFCBORInteger *numberOfBytes = [self decodeIntegerFromInputStream:inputStream header:integerHeader];
    
    NSData *textStringData = [self readObjectFromInputStream:inputStream header:header size:numberOfBytes.value];
    YKFAssertReturnValue(textStringData, @"CBOR - Decoding input stream error. Could not read Text String.", nil);
    
    return [self decodeTextString:textStringData];
}

+ (YKFCBORArray *)decodeArrayFromInputStream:(NSInputStream *)inputStream header:(UInt8)header {
    UInt8 integerHeader = header & ~YKFCBORArrayTagMask; // Remove MT mask from the number of elements.
    YKFCBORInteger *numberOfElements = [self decodeIntegerFromInputStream:inputStream header:integerHeader];
    YKFAssertReturnValue(numberOfElements, @"CBOR - Decoding input stream error. Could not decode array count.", nil);
    
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:numberOfElements.value];
    for (int i = 0; i < numberOfElements.value; ++i) {
        id element = [self decodeObjectFrom:inputStream];
        YKFAssertReturnValue(element, @"CBOR - Decoding input stream error. Could not decode array element.", nil);
        [array addObject:element];
    }

    return YKFCBORArray([array copy]);
}

+ (YKFCBORMap *)decodeMapFromInputStream:(NSInputStream *)inputStream header:(UInt8)header {
    UInt8 integerHeader = header & ~YKFCBORMapTagMask; // Remove MT mask from the number of elements.
    YKFCBORInteger *numberOfPairs = [self decodeIntegerFromInputStream:inputStream header:integerHeader];
    YKFAssertReturnValue(numberOfPairs, @"CBOR - Decoding input stream error. Could not decode number of map pairs.", nil);
    
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:numberOfPairs.value];
    for (int i = 0; i < numberOfPairs.value; ++i) {
        id key = [self decodeObjectFrom:inputStream];
        YKFAssertReturnValue(key, @"CBOR - Decoding input stream error. Could not decode map key.", nil);

        id value = [self decodeObjectFrom:inputStream];
        YKFAssertReturnValue(value, @"CBOR - Decoding input stream error. Could not decode map value.", nil);
        
        // Security check: Verify if the key already exists in the decoded map. A map with duplicated keys is invalid.
        YKFAssertReturnValue(!dictionary[key], @"CBOR - The key already exists in the map.", nil);
        dictionary[key] = value;
    }
    
    return YKFCBORMap([dictionary copy]);
}

+ (YKFCBORBool *)decodeBoolFromInputStream:(NSInputStream *)inputStream header:(UInt8)header {
    YKFAssertReturnValue(header == 0xF4 || header == 0xF5, @"CBOR - Decoding input stream error. Could not decode bool value.", nil);
    return header == 0xF4 ? YKFCBORBool(NO) : YKFCBORBool(YES);
}

#pragma mark -

+ (NSData *)readObjectFromInputStream:(NSInputStream *)inputStream header:(UInt8)header size:(NSUInteger)size {
    NSMutableData *objectData = [[NSMutableData alloc] initWithCapacity:size + 1];
    [objectData appendBytes:&header length:1];
    if (size) {
        NSData *readData = [inputStream dequeueBytes:size];
        if (!readData) {
            return nil;
        }
        [objectData appendData:readData];
    }
    return objectData;
}

#pragma mark - Primitive Decoding

+ (YKFCBORInteger *)decodeInteger:(nonnull NSData *)data {
    YKFAssertReturnValue(data.length, @"CBOR - Cannot decode from empty data.", nil);
    
    UInt8 *bytes = (UInt8 *)data.bytes;
    
    BOOL isNegative = bytes[0] & YKFCBORNegativeIntegerTagMask;
    bytes[0] = bytes[0] & ~YKFCBORNegativeIntegerTagMask; // remove sign.
    
    NSInteger value = 0;
    
    switch (data.length) {
        case 1:
            value = bytes[0];
            break;
        case 2:
            value = bytes[1];
            break;
        case 3:
            value = CFSwapInt16BigToHost(*((UInt16 *)(&bytes[1])));
            break;
        case 5:
            value = CFSwapInt32BigToHost(*((UInt32 *)(&bytes[1])));
            break;
            
        case 9: {
            UInt64 parsedValue = CFSwapInt64BigToHost(*((UInt64 *)(&bytes[1])));
            
            // Avoid overflow for values which cannot be represented on a NSInteger.
            YKFAssertReturnValue(parsedValue <= INT64_MAX, @"CBOR - Cannot decode integer value. The value is too large.", nil);
            value = (NSInteger)parsedValue;
        }
        break;
            
        default:
            return nil;
    }
    
    value = isNegative ? -(value + 1) : value;
    return YKFCBORInteger(value);
}

+ (YKFCBORByteString *)decodeByteString:(nonnull NSData *)data {
    YKFAssertReturnValue(data.length, @"CBOR - Cannot decode from empty byte string data.", nil);
    if (data.length == 1) {
        return YKFCBORByteString([NSData data]);
    }
    return YKFCBORByteString([data subdataWithRange:NSMakeRange(1, data.length - 1)]);
}

+ (YKFCBORTextString *)decodeTextString:(nonnull NSData *)data {
    YKFAssertReturnValue(data.length, @"CBOR - Cannot decode from empty text string data.", nil);
    
    if (data.length == 1) {
        return YKFCBORTextString(@"");
    }
    
    NSData *textStringData = [data subdataWithRange:NSMakeRange(1, data.length -1)];
    NSString *stringValue = [[NSString alloc] initWithData:textStringData encoding:NSUTF8StringEncoding];
    YKFAssertReturnValue(stringValue, @"CBOR - Cannot decode UTF8 string data.", nil);
    
    return YKFCBORTextString(stringValue);
}

#pragma mark - CBOR to Foundation

+ (id)convertCBORObjectToFoundationType:(id)cborObject {
    if ([cborObject isKindOfClass:YKFCBORInteger.class]) {
        return @(((YKFCBORInteger *)cborObject).value);
    }
    
    if ([cborObject isKindOfClass:YKFCBORByteString.class]) {
        return [((YKFCBORByteString *)cborObject).value copy];
    }
    
    if ([cborObject isKindOfClass:YKFCBORTextString.class]) {
        return [((YKFCBORTextString *)cborObject).value copy];
    }
    
    if ([cborObject isKindOfClass:YKFCBORBool.class]) {
        return @(((YKFCBORBool *)cborObject).value);
    }
    
    if ([cborObject isKindOfClass:YKFCBORArray.class]) {
        YKFCBORArray *cborArray = (YKFCBORArray *)cborObject;
        NSMutableArray *tempArray = [[NSMutableArray alloc] initWithCapacity:cborArray.value.count];
        
        for (id arrayObject in cborArray.value) {
            id arrayElement = [self convertCBORObjectToFoundationType:arrayObject];
            if (!arrayElement) {
                return nil;
            }
            [tempArray addObject:arrayElement];
        }
        
        return [tempArray copy];
    }
    
    if ([cborObject isKindOfClass:YKFCBORMap.class]) {
        YKFCBORMap *cborMap = (YKFCBORMap *)cborObject;
        NSMutableDictionary *tempDictionary = [[NSMutableDictionary alloc] initWithCapacity:cborMap.value.count];
        NSArray *dictionaryKeys = cborMap.value.allKeys;
        
        for (id key in dictionaryKeys) {
            id value = cborMap.value[key];
            id dictionaryKey = [self convertCBORObjectToFoundationType:key];
            id dictionaryValue = [self convertCBORObjectToFoundationType:value];
            if (!dictionaryKey || !dictionaryValue) {
                return nil;
            }
            tempDictionary[dictionaryKey] = dictionaryValue;
        }
        
        return [tempDictionary copy];
    }
    
    return nil;
}

@end

#pragma mark - NSInputStream(YKFCBORDecoder)

@implementation NSInputStream(YKFCBORDecoder)

- (UInt8)dequeueHead:(BOOL *)error {
    NSData *headData = [self dequeueBytes:1];
    if (!headData) {
        *error = YES;
        return 0;
    }
    return ((UInt8 *)(headData.bytes))[0];
}

- (NSData *)dequeueBytes:(NSUInteger)numberOfBytes {
    YKFAssertReturnValue(self.streamStatus == NSStreamStatusOpen, @"CBOR - Input stream not opened.", nil);
    YKFAssertReturnValue(self.hasBytesAvailable, @"CBOR - Cannot read from empty input stream.", nil);
    YKFAssertReturnValue(numberOfBytes > 0 , @"CBOR - Cannot read 0 bytes.", nil);

    UInt8 *buffer = malloc(numberOfBytes);
    if (!buffer) {
        return nil;
    }
    memset(buffer, 0, numberOfBytes);
    
    NSInteger bytesRead = [self read:buffer maxLength:numberOfBytes];
    if (bytesRead != numberOfBytes) {
        memset(buffer, 0, numberOfBytes);
        free(buffer);
        return nil;
    }
    
    NSData *returnValue = [NSData dataWithBytes:buffer length:numberOfBytes];
    
    // Clear the buffer
    memset(buffer, 0, numberOfBytes);
    free(buffer);
    
    return returnValue;
}

@end

