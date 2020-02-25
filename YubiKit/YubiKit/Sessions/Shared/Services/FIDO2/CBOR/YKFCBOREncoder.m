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

#import "YKFCBOREncoder.h"
#import "YKFCBORTag.h"
#import "YKFAssert.h"

@implementation YKFCBOREncoder

#pragma mark - Integer (Major Types 0 and 1)

+ (NSData *)encodeInteger:(YKFCBORInteger *)cborInteger {
    YKFAssertReturnValue(cborInteger, @"CBOR Encoding - Cannot encode empty CBOR integer.", nil);
    
    NSInteger value = cborInteger.value;
    
    if (labs(value) <= INT8_MAX) {
        return [self encodeSInt8:(SInt8)value];
    }
    if (labs(value) <= UINT8_MAX) {
        return value < 0 ? [self encodeSInt16:(SInt16)value] : [self encodeUInt8:(UInt8)value];
    }
    if (labs(value) <= INT16_MAX) {
        return [self encodeSInt16:(SInt16)value];
    }
    if (labs(value) <= UINT16_MAX) {
        return value < 0 ? [self encodeSInt32:(SInt32)value] : [self encodeUInt16:(UInt16)value];
    }
    if (labs(value) <= INT32_MAX) {
        return [self encodeSInt32:(SInt32)value];
    }
    if (labs(value) <= UINT32_MAX) {
        return value < 0 ? [self encodeSInt64:(SInt64)value] : [self encodeUInt32:(UInt32)value];
    }

    return [self encodeSInt64:(SInt64)value];
}

#pragma mark - Byte String (Major Type 2)

+ (NSData *)encodeByteString:(YKFCBORByteString *)cborByteString {
    YKFAssertReturnValue(cborByteString, @"CBOR Encoding - Cannot encode nil CBOR byte string.", nil);
    
    NSData *byteString = cborByteString.value;
    return [self encodeData:byteString tagMask:YKFCBORByteStringTagMask];
}

#pragma mark - Text String (Major Type 3)

+ (NSData *)encodeTextString:(YKFCBORTextString *)cborTextString {
    YKFAssertReturnValue(cborTextString, @"CBOR Encoding - Cannot encode nil CBOR text string.", nil);
    
    NSString *string = cborTextString.value;
    YKFAssertReturnValue(string, @"CBOR Encoding - Cannot encode nil string.", nil);
    
    NSData *utf8EncodedData = [string dataUsingEncoding:NSUTF8StringEncoding];    
    return [self encodeData:utf8EncodedData tagMask:YKFCBORTextStringTagMask];
}

#pragma mark - Array (Major Type 4)

+ (NSData *)encodeArray:(YKFCBORArray *)cborArray {
    YKFAssertReturnValue(cborArray, @"CBOR Encoding - Cannot encode empty CBOR array.", nil);
    
    NSArray *array = cborArray.value;
    YKFAssertReturnValue(cborArray, @"CBOR Encoding - Cannot encode empty/nil array.", nil);
    
    YKFCBORInteger *arrayLength = YKFCBORInteger(array.count);
    NSData *encodedLength = [self encodeInteger:arrayLength];
    NSMutableData *encodedArray = [[NSMutableData alloc] initWithData:encodedLength];
    
    // Set major type 4.
    UInt8 *encodedValueBytes = encodedArray.mutableBytes;
    encodedValueBytes[0] = encodedValueBytes[0] | YKFCBORArrayTagMask;

    // Append the elements.
    for (id element in array) {
        NSData *encodedElement = [self encodeObject:element];
        NSAssert(encodedElement, @"Cannot encode all the elements in the array. Unknown type: %@",
                 NSStringFromClass(((NSObject *)element).class));
        if (!encodedElement) {
            return nil;
        }
        [encodedArray appendData:encodedElement];
    }
    
    return [encodedArray copy];
}

#pragma mark - Map (Major Type 5)

+ (NSData *)encodeMap:(YKFCBORMap *)cborMap {
    YKFAssertReturnValue(cborMap, @"CBOR Encoding - Cannot encode nil CBOR map.", nil);
    
    NSDictionary *map = cborMap.value;
    YKFAssertReturnValue(map, @"CBOR Encoding - Cannot encode nil dictionary.", nil);
    
    YKFCBORInteger *mapPairs = YKFCBORInteger(map.count);
    NSData *encodedPairs = [self encodeInteger:mapPairs];
    NSMutableData *encodedMap = [[NSMutableData alloc] initWithData:encodedPairs];
    
    // Set major type 5.
    UInt8 *encodedValueBytes = encodedMap.mutableBytes;
    encodedValueBytes[0] = encodedValueBytes[0] | YKFCBORMapTagMask;

    // Append the pairs sorted by keys.
    NSArray *keys = [map.allKeys sortedArrayUsingSelector:@selector(compare:)];
    
    for (id key in keys) {
        id keyValue = map[key];
        
        NSData *encodedKey = [self encodeObject:key];
        NSData *encodedKeyValue = [self encodeObject:keyValue];
        
        NSAssert(encodedKey, @"Cannot encode all the elements in the map. Unknown key type: %@",
                 NSStringFromClass(((NSObject *)key).class));
        NSAssert(encodedKeyValue, @"Cannot encode all the elements in the map. Unknown key value type: %@",
                 NSStringFromClass(((NSObject *)keyValue).class));
        
        if (!encodedKey || !encodedKeyValue) {
            return nil;
        }
        
        [encodedMap appendData:encodedKey];
        [encodedMap appendData:encodedKeyValue];
    }
    
    return [encodedMap copy];
}

#pragma mark - Boolean (Appendix B.  Jump Table)

+ (NSData *)encodeBool:(YKFCBORBool *)cborBool {
    YKFAssertReturnValue(cborBool, @"CBOR Encoding - Cannot encode empty CBOR bool.", nil);
    
    UInt8 encoded = cborBool.value ? 0xF5 : 0xF4;
    return [NSData dataWithBytes:&encoded length:1];
}

#pragma mark - Helpers

+ (NSData *)encodeUInt8:(UInt8)value {
    if (value < 24) {
        return [NSData dataWithBytes:&value length:1];
    }
    const UInt8 bytes[] = {YKFCBORUInt8Tag, value};
    return [NSData dataWithBytes:bytes length:2];
}

+ (NSData *)encodeUInt16:(UInt16)value {
    NSMutableData *buffer = [[NSMutableData alloc] init];
    UInt16 bigUInt16 = CFSwapInt16HostToBig(value);
    
    [buffer appendBytes:&YKFCBORUInt16Tag length:1];
    [buffer appendBytes:&bigUInt16 length:sizeof(UInt16)];
    
    return [buffer copy];
}

+ (NSData *)encodeUInt32:(UInt32)value {
    NSMutableData *buffer = [[NSMutableData alloc] init];
    UInt32 bigUInt32 = CFSwapInt32HostToBig(value);
    
    [buffer appendBytes:&YKFCBORUInt32Tag length:1];
    [buffer appendBytes:&bigUInt32 length:sizeof(UInt32)];
    
    return [buffer copy];
}

+ (NSData *)encodeUInt64:(UInt64)value {
    NSMutableData *buffer = [[NSMutableData alloc] init];
    UInt64 bigUInt64 = CFSwapInt64HostToBig(value);
    
    [buffer appendBytes:&YKFCBORUInt64Tag length:1];
    [buffer appendBytes:&bigUInt64 length:sizeof(UInt64)];
    
    return [buffer copy];
}

+ (NSData *)encodeSInt8:(SInt8)value {
    if (value >= 0) {
        return [self encodeUInt8:value];
    }
    value = -1 - value;
    
    if (value < 24) {
        value |= YKFCBORNegativeIntegerTagMask;
        return [NSData dataWithBytes:&value length:1];
    }
    
    const UInt8 bytes[] = {YKFCBORSInt8Tag, value};
    return [NSData dataWithBytes:bytes length:2];
}

+ (NSData *)encodeSInt16:(SInt16)value {
    if (value >= 0) {
        return [self encodeUInt16:value];
    }
    value = -1 - value;
    
    NSMutableData *buffer = [[NSMutableData alloc] init];
    UInt16 bigUInt16 = CFSwapInt16HostToBig(value);
    
    [buffer appendBytes:&YKFCBORSInt16Tag length:1];
    [buffer appendBytes:&bigUInt16 length:sizeof(UInt16)];
    
    return [buffer copy];
}

+ (NSData *)encodeSInt32:(SInt32)value {
    if (value >= 0) {
        return [self encodeUInt32:value];
    }
    value = -1 - value;
    
    NSMutableData *buffer = [[NSMutableData alloc] init];
    UInt32 bigUInt32 = CFSwapInt32HostToBig(value);
    
    [buffer appendBytes:&YKFCBORSInt32Tag length:1];
    [buffer appendBytes:&bigUInt32 length:sizeof(UInt32)];
    
    return [buffer copy];
}

+ (NSData *)encodeSInt64:(SInt64)value {
    if (value >= 0) {
        return [self encodeUInt64:value];
    }
    value = -1 - value;
    
    NSMutableData *buffer = [[NSMutableData alloc] init];
    UInt64 bigUInt64 = CFSwapInt64HostToBig(value);
    
    [buffer appendBytes:&YKFCBORSInt64Tag length:1];
    [buffer appendBytes:&bigUInt64 length:sizeof(UInt64)];
    
    return [buffer copy];
}

+ (NSData *)encodeData:(NSData *)value tagMask:(UInt8)tagMask {
    YKFAssertReturnValue(value, @"CBOR Encoding - Cannot encode nil data.", nil);
    
    YKFCBORInteger *dataLength = YKFCBORInteger(value.length);
    NSMutableData *encodedValue = nil;
    if (dataLength) {
        NSData *encodedLength = [self encodeInteger:dataLength];
        encodedValue = [[NSMutableData alloc] initWithData:encodedLength];
        [encodedValue appendData:value];
        
        // Set the major type 2.
        UInt8 *encodedValueBytes = encodedValue.mutableBytes;
        encodedValueBytes[0] = encodedValueBytes[0] | tagMask;
    } else {
        // Set only the major type.
        encodedValue = [[NSMutableData alloc] initWithCapacity:1];
        [encodedValue appendBytes:&tagMask length:1];
    }
    
    return [encodedValue copy];
}

+ (NSData *)encodeObject:(id)object {
    YKFAssertReturnValue(object, @"CBOR Encoding - Cannot encode a nil object.", nil);
    
    if ([object isKindOfClass:YKFCBORInteger.class]) {
        YKFCBORInteger *integer = (YKFCBORInteger *)object;
        return [self encodeInteger:integer];
    }
    if ([object isKindOfClass:YKFCBORByteString.class]) {
        YKFCBORByteString *byteString = (YKFCBORByteString *)object;
        return [self encodeByteString:byteString];
    }
    if ([object isKindOfClass:YKFCBORTextString.class]) {
        YKFCBORTextString *textString = (YKFCBORTextString *)object;
        return [self encodeTextString:textString];
    }
    if ([object isKindOfClass:YKFCBORArray.class]) {
        YKFCBORArray *array = (YKFCBORArray *)object;
        return [self encodeArray:array];
    }
    if ([object isKindOfClass:YKFCBORMap.class]) {
        YKFCBORMap *map = (YKFCBORMap *)object;
        return [self encodeMap:map];
    }
    if ([object isKindOfClass:YKFCBORBool.class]) {
        YKFCBORBool *boolean = (YKFCBORBool *)object;
        return [self encodeBool:boolean];
    }
    
    return nil;
}

@end
