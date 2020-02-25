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

#import "YKFKeySessionError.h"

typedef NS_ENUM(NSUInteger, YKFKeyU2FErrorCode) {
    
    /*! The host application tried to perform an U2F sign operation with a key handle which was not generated with the current key.
     @discussion
     This error happens when the application tries to authenticate without registering first. Ideally the authentication flow of
     the application should not allow this to happen.
     */
    YKFKeyU2FErrorCodeU2FSigningUnavailable = 0x000010
};

NS_ASSUME_NONNULL_BEGIN

/*!
 @class
    YKFKeyU2FError
 @abstract
    Error type returned by the YKFKeyU2FService.
 */
@interface YKFKeyU2FError: YKFKeySessionError
@end

NS_ASSUME_NONNULL_END
