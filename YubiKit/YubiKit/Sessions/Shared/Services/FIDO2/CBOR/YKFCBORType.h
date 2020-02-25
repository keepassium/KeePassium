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

#import <Foundation/Foundation.h>

/*
 YKFCBORTypeProtocol
 */

@protocol YKFCBORTypeProtocol<NSObject>

@property (readonly) NSUInteger hash;

- (BOOL)isEqual:(id)object;
- (NSComparisonResult)compare:(id)other;

- (NSString *)description;

@end

/*
 YKFCBORInteger
 */

#define YKFCBORInteger(value) [YKFCBORInteger cborIntegerWithValue:value]

@interface YKFCBORInteger: NSObject<NSCopying, YKFCBORTypeProtocol>

@property (nonatomic) NSInteger value;
+ (YKFCBORInteger *)cborIntegerWithValue:(NSInteger)value;

@end

/*
 YKFCBORByteString
 */

#define YKFCBORByteString(value) [YKFCBORByteString cborByteStringWithValue:value]

@interface YKFCBORByteString: NSObject<NSCopying, YKFCBORTypeProtocol>

@property (nonatomic) NSData *value;
+ (YKFCBORByteString *)cborByteStringWithValue:(NSData *)value;

@end

/*
 YKFCBORTextString
 */

#define YKFCBORTextString(value) [YKFCBORTextString cborTextStringWithValue:value]

@interface YKFCBORTextString: NSObject<NSCopying, YKFCBORTypeProtocol>

@property (nonatomic) NSString *value;
+ (YKFCBORTextString *)cborTextStringWithValue:(NSString *)value;

@end

/*
 YKFCBORArray
 */

#define YKFCBORArray(value) [YKFCBORArray cborArrayWithValue:value]

@interface YKFCBORArray: NSObject<NSCopying, YKFCBORTypeProtocol>

@property (nonatomic) NSArray *value;
+ (YKFCBORArray *)cborArrayWithValue:(NSArray *)value;

@end

/*
 YKFCBORMap
 */

#define YKFCBORMap(value) [YKFCBORMap cborMapWithValue:value]

@interface YKFCBORMap: NSObject<NSCopying, YKFCBORTypeProtocol>

@property (nonatomic) NSDictionary *value;
+ (YKFCBORMap *)cborMapWithValue:(NSDictionary *)value;

@end

/*
 YKFCBORBool
 */

#define YKFCBORBool(value) [YKFCBORBool cborBoolWithValue:value]

@interface YKFCBORBool: NSObject<NSCopying, YKFCBORTypeProtocol>

@property (nonatomic) BOOL value;
+ (YKFCBORBool *)cborBoolWithValue:(BOOL)value;

@end
