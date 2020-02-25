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

/*!
 @constant
    YKFNFCErrorDomain
 @abstract
    Domain for errors from NFC.
 */
extern NSString* const YKFNFCErrorDomain;

/*!
 @class
    YKFNFCReadError
 @abstract
    Error from NFC.
 */
@interface YKFNFCError : NSError

- (instancetype)init NS_UNAVAILABLE;

@end

/*!
 @constant
    YKFNFCReadErrorNoTokenAfterScanCode
 @abstract
    When the library was not able to retreive a OTP token from the NDEF payload.
 */
extern int const YKFNFCReadErrorNoTokenAfterScanCode;

NS_ASSUME_NONNULL_END
