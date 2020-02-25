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
#import "YKFPCSCLayer.h"

@interface FakeYKFPCSCLayer: NSObject<YKFPCSCLayerProtocol>

@property (nonatomic) BOOL addCardToContextResponse;
@property (nonatomic) BOOL addContextResponse;
@property (nonatomic) BOOL cardIsValidResponse;
@property (nonatomic) BOOL contextIsValidResponse;
@property (nonatomic) BOOL removeCardResponse;
@property (nonatomic) BOOL removeContextResponse;

@property (nonatomic) SInt64 connectCardResponse;
@property (nonatomic) SInt32 contextForCardResponse;
@property (nonatomic) SInt64 disconnectCardResponse;
@property (nonatomic) SInt64 reconnectCardResponse;
@property (nonatomic) SInt32 getCardStateResponse;
@property (nonatomic) SInt64 getStatusChangeResponse;

@property (nonatomic) SInt64 listReadersResponse;
@property (nonatomic) NSString *listReadersResponseParam;

@property (nonatomic) SInt64 transmitResponse;
@property (nonatomic) NSData *transmitResponseParam;
@property (nonatomic) NSData *transmitCommand;

@property (nonatomic) NSString *getCardSerialResponse;
@property (nonatomic) NSString *stringifyErrorResponse;

@end
