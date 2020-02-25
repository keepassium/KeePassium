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

NS_ASSUME_NONNULL_BEGIN

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name NSData(NSData_WebSafeBase64)
 * ---------------------------------------------------------------------------------------------------------------------
 */

@interface NSData(NSData_WebSafeBase64)

/*!
 @method ykf_initWithWebsafeBase64EncodedString:dataLength:
 
 @return
    A new data object created with a websafeBase64/base64url encoded string.
 
 @param websafeBase64EncodedData
    The websafe Base64 encoded string.
 @param dataLen
    The expected data length of the output. If the output is smaller the data will be padded to match the length.
 */
- (nullable instancetype)ykf_initWithWebsafeBase64EncodedString:(nonnull NSString *)websafeBase64EncodedData dataLength:(NSUInteger)dataLen;

/*!
 @method ykf_websafeBase64EncodedString
 
 @return
    The websafeBase64/base64url encoded string of the data.
 */
- (nullable NSString *)ykf_websafeBase64EncodedString;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name NSData(NSData_SHAAdditions)
 * ---------------------------------------------------------------------------------------------------------------------
 */

@interface NSData(NSData_SHAAdditions)

/*!
 @method ykf_SHA1
 
 @return
    The SHA1 hash of the data.
 */
- (NSData *)ykf_SHA1;

/*!
 @method ykf_SHA256
 
 @return
    The SHA256 hash of the data.
 */
- (NSData *)ykf_SHA256;

/*!
 @method ykf_SHA512
 
 @return
    The SHA512 hash of the data.
 */
- (NSData *)ykf_SHA512;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name NSData(NSData_Base32Additions)
 * ---------------------------------------------------------------------------------------------------------------------
 */

@interface NSData(NSData_Base32Additions)

/*!
 @method ykf_dataWithBase32String:
 
 @return
    A data object from a Base32 encoded string or nil if the string could not be parsed.
 */
+ (nullable NSData *)ykf_dataWithBase32String:(NSString *)base32String;

@end

NS_ASSUME_NONNULL_END
