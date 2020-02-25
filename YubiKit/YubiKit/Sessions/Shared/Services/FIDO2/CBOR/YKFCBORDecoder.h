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
#import "YKFCBORType.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 The interface for a CTAP2 CBOR decoder.
 */
@protocol YKFCBORDecoderProtocol<NSObject>

/*!
 @abstract
    Decodes a CBOR type from an input stream.
 @returns
    The object or nil if the object could not be parsed.
 */
+ (nullable id)decodeObjectFrom:(NSInputStream *)inputStream;

/*!
 @abstract
    Converts a CBOR type to a foundation type object (e.g. YKFCBORArray -> NSArray).
 @returns
    The foudation type object (e.g. NSNumber, NSDictionary etc) or nil if the object could not be converted.
 */
+ (nullable id)convertCBORObjectToFoundationType:(id)cborObject;

@end

/*!
 CTAP2 CBOR decoder.
 */
@interface YKFCBORDecoder: NSObject<YKFCBORDecoderProtocol>
@end

NS_ASSUME_NONNULL_END
