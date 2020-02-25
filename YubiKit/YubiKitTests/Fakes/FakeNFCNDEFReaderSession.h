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
#import "NFCNDEFReaderSession+Testing.h"

@interface FakeNFCNDEFReaderSession : NSObject<YKFNFCNDEFReaderSessionProtocol>

@property (nonatomic, weak) id<NFCNDEFReaderSessionDelegate> delegate;
@property (nonatomic, assign) BOOL invalidateAfterFirstRead;
@property (nonatomic) dispatch_queue_t dispatchQueue;

// Invocation properties
@property (nonatomic, assign) BOOL sessionStarted;

@end
