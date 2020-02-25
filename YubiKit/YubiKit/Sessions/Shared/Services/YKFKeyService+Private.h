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
#import "YKFKeyService.h"
#import "YKFKeyRequest.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 Receives updates when the service performs a set of operations.
 The service can be its own delegate or it can receive forwarded updates from a central delegate.
 */
@protocol YKFKeyServiceDelegate<NSObject>

- (void)keyService:(YKFKeyService *)service willExecuteRequest:(nullable YKFKeyRequest *)request;

@end

@interface YKFKeyService()<YKFKeyServiceDelegate>

@property (nonatomic, weak) id<YKFKeyServiceDelegate> delegate;

/// Removes the YLP headers and status code from the response data received from a key command response.
- (NSData *)dataFromKeyResponse:(NSData *)response;

/// Returns the status code from a response received from a key command response.
- (UInt16)statusCodeFromKeyResponse:(NSData *)response;

/// Returns the first byte value of the status code.
- (UInt8)shortStatusCodeFromStatusCode:(UInt16)statusCode;

@end

NS_ASSUME_NONNULL_END
