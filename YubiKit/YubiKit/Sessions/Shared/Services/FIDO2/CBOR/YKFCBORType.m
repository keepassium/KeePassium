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

#import "YKFCBORType.h"

#pragma mark - YKFCBORInteger

@implementation YKFCBORInteger

+ (YKFCBORInteger *)cborIntegerWithValue:(NSInteger)value {
    YKFCBORInteger *cborInteger = [[YKFCBORInteger alloc] init];
    cborInteger.value = value;
    return cborInteger;
}

- (NSUInteger)hash {
    return self.value;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return YKFCBORInteger(self.value);
}

- (NSComparisonResult)compare:(id)other {
    NSParameterAssert([other isKindOfClass:self.class]);
    YKFCBORInteger *otherInteger = (YKFCBORInteger *)other;
    
    if (self.value < otherInteger.value) { return NSOrderedAscending; }
    if (self.value > otherInteger.value) { return NSOrderedDescending; }    
    return NSOrderedSame;
}

- (BOOL)isEqual:(id)object {
    NSParameterAssert([object isKindOfClass:self.class]);
    YKFCBORInteger *otherInteger = (YKFCBORInteger *)object;
    
    return self.value == otherInteger.value;
}

- (NSString *)description {
    NSString *className = NSStringFromClass(self.class);
    return [NSString stringWithFormat:@"%@: %ld", className, (long)self.value];
}

@end

#pragma mark - YKFCBORByteString

@implementation YKFCBORByteString

+ (YKFCBORByteString *)cborByteStringWithValue:(NSData *)value {
    YKFCBORByteString *byteString = [[YKFCBORByteString alloc] init];
    byteString.value = value;
    return byteString;
}

- (NSUInteger)hash {
    return [self.value hash];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return [YKFCBORByteString cborByteStringWithValue:self.value];
}

- (NSComparisonResult)compare:(id)other {
    NSAssert(NO, @"Cannot compare NSData. NSData should not be used as a key.");
    return NSOrderedSame;
}

- (BOOL)isEqual:(id)object {
    NSParameterAssert([object isKindOfClass:self.class]);
    YKFCBORByteString *otherByteString = (YKFCBORByteString *)object;

    return [self.value isEqualToData:otherByteString.value];
}

- (NSString *)description {
    NSString *className = NSStringFromClass(self.class);
    return [NSString stringWithFormat:@"%@: %@", className, self.value.description];
}

@end

#pragma mark - YKFCBORTextString

@implementation YKFCBORTextString

+ (YKFCBORTextString *)cborTextStringWithValue:(NSString *)value {
    YKFCBORTextString *textString = [[YKFCBORTextString alloc] init];
    textString.value = value;
    return textString;
}

- (NSUInteger)hash {
    return [self.value hash];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return [YKFCBORTextString cborTextStringWithValue:self.value];
}

- (NSComparisonResult)compare:(id)other {
    NSParameterAssert([other isKindOfClass:self.class]);
    YKFCBORTextString *otherTextString = (YKFCBORTextString *)other;
    
    if (self.value.length < otherTextString.value.length) {
        return NSOrderedAscending;
    } else if (self.value.length > otherTextString.value.length) {
        return NSOrderedDescending;
    } else {
        return [self.value compare:otherTextString.value];
    }
}

- (BOOL)isEqual:(id)object {
    NSParameterAssert([object isKindOfClass:self.class]);
    YKFCBORTextString *otherTextString = (YKFCBORTextString *)object;
    
    return [self.value isEqualToString:otherTextString.value];
}

- (NSString *)description {
    NSString *className = NSStringFromClass(self.class);
    return [NSString stringWithFormat:@"%@: %@", className, self.value];
}

@end

#pragma mark - YKFCBORArray

@implementation YKFCBORArray

+ (YKFCBORArray *)cborArrayWithValue:(NSArray *)value {
    YKFCBORArray *array = [[YKFCBORArray alloc] init];
    array.value = value;
    return array;
}

- (NSUInteger)hash {
    NSAssert(NO, @"Cannot hash NSArray. NSArrays should not be used as keys.");
    return 0;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return [YKFCBORArray cborArrayWithValue:self.value];
}

- (NSComparisonResult)compare:(id)otherArray {
    NSAssert(NO, @"Cannot compare NSArray. NSArrays should not be used as keys.");
    return NSOrderedSame;
}

- (BOOL)isEqual:(id)object {
    NSParameterAssert([object isKindOfClass:self.class]);
    YKFCBORArray *otherArray = (YKFCBORArray *)object;
    
    return [self.value isEqualToArray:otherArray.value];
}

- (NSString *)description {
    NSString *className = NSStringFromClass(self.class);
    return [NSString stringWithFormat:@"%@: %@", className, self.value.description];
}

@end

#pragma mark - YKFCBORMap

@implementation YKFCBORMap

+ (YKFCBORMap *)cborMapWithValue:(NSDictionary *)value {
    YKFCBORMap *map = [[YKFCBORMap alloc] init];
    map.value = value;
    return map;
}

- (NSUInteger)hash {
    NSAssert(NO, @"Cannot hash NSDictionary. NSDictionary should not be used as a key.");
    return 0;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return [YKFCBORMap cborMapWithValue:self.value];
}

- (NSComparisonResult)compare:(id)otherMap {
    NSAssert(NO, @"Cannot compare NSDisctionary. NSDisctionary should not be used as a key.");
    return NSOrderedSame;
}

- (BOOL)isEqual:(id)object {
    NSParameterAssert([object isKindOfClass:self.class]);
    YKFCBORMap *otherMap = (YKFCBORMap *)object;

    return [self.value isEqualToDictionary:otherMap.value];
}

- (NSString *)description {
    NSString *className = NSStringFromClass(self.class);
    return [NSString stringWithFormat:@"%@: %@", className, self.value];
}

@end

#pragma mark - YKFCBORBool

@implementation YKFCBORBool

+ (YKFCBORBool *)cborBoolWithValue:(BOOL)value {
    YKFCBORBool *cborBool = [[YKFCBORBool alloc] init];
    cborBool.value = value;
    return cborBool;
}

- (NSUInteger)hash {
    NSAssert(NO, @"Cannot hash Bool. Bools should not be used as keys.");
    return 0;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return [YKFCBORBool cborBoolWithValue:self.value];
}

- (NSComparisonResult)compare:(id)otherBool {
    NSAssert(NO, @"Cannot compare Bool. Bools should not be used as keys.");
    return NSOrderedSame;
}

- (BOOL)isEqual:(id)object {
    NSParameterAssert([object isKindOfClass:self.class]);
    YKFCBORBool *otherBool = (YKFCBORBool *)object;

    return self.value == otherBool.value;
}

- (NSString *)description {
    NSString *className = NSStringFromClass(self.class);
    return [NSString stringWithFormat:@"%@: %@", className, self.value ? @"true" : @"false"];
}

@end
