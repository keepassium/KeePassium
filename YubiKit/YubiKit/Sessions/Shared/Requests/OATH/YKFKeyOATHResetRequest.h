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
#import "YKFKeyOATHRequest.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFKeyOATHResetRequest
 
 @abstract
    Request for resetting the OATH appllication on the key. This request maps to the RESET command
    from YOATH protocol: https://developers.yubico.com/OATH/YKOATH_Protocol.html
 
 @discussion
    This request is destructive and removes all stored credentials from the key. The reset
    command does not require validation if a PIN was set on the OATH application
    from the key. If the OATH application is password protected, the reset command will remove
    the authentication as well.
 */
@interface YKFKeyOATHResetRequest: YKFKeyOATHRequest
@end

NS_ASSUME_NONNULL_END
