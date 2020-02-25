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
#import "YKFKeyRequest.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFKeyFIDO2Request
 
 @abstract
    Base clase for all FIDO2 requests. Use the subclasses of this type  for sending specific
    FIDO2 requests to the key.
 */
@interface YKFKeyFIDO2Request: YKFKeyRequest
@end

NS_ASSUME_NONNULL_END
