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
#import <CoreNFC/CoreNFC.h>
#import "YKFKeyConnectionControllerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
@interface YKFNFCConnectionController: NSObject<YKFKeyConnectionControllerProtocol>

- (instancetype)initWithNFCTag:(id<NFCISO7816Tag>)tag operationQueue:(NSOperationQueue *)operationQueue;

@end

NS_ASSUME_NONNULL_END
