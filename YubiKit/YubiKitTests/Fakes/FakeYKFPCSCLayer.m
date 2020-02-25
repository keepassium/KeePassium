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

#import "FakeYKFPCSCLayer.h"

@implementation FakeYKFPCSCLayer

@synthesize cardState;
@synthesize cardSerial;
@synthesize cardAtr;
@synthesize statusChange;
@synthesize deviceFriendlyName;
@synthesize deviceModelName;
@synthesize deviceVendorName;

- (NSString *)cardSerial {
    return self.getCardSerialResponse;
}

- (NSData *)cardAtr {
    return [NSData data];
}

- (SInt32)cardState {
    return self.getCardStateResponse;
}

- (SInt64)statusChange {
    return self.getStatusChangeResponse;
}

- (BOOL)addCard:(SInt32)card toContext:(SInt32)context {
    return self.addCardToContextResponse;
}

- (BOOL)addContext:(SInt32)context {
    return self.addContextResponse;
}

- (BOOL)cardIsValid:(SInt32)card {
    return self.cardIsValidResponse;
}

- (SInt64)connectCard {
    return self.connectCardResponse;
}

- (SInt32)contextForCard:(SInt32)card {
    return self.contextForCardResponse;
}

- (BOOL)contextIsValid:(SInt32)context {
    return self.contextIsValidResponse;
}

- (SInt64)disconnectCard {
    return self.disconnectCardResponse;
}

- (SInt64)listReaders:(NSString **)yubikeyReaderName {
    *yubikeyReaderName = self.listReadersResponseParam;
    return self.listReadersResponse;
}

- (SInt64)reconnectCard {
    return self.reconnectCardResponse;
}

- (BOOL)removeCard:(SInt32)card {
    return self.removeCardResponse;
}

- (BOOL)removeContext:(SInt32)context {
    return self.removeContextResponse;
}

- (NSString *)stringifyError:(SInt64)errorCode {
    return self.stringifyErrorResponse;
}

- (SInt64)transmit:(NSData *)commandData response:(NSData **)response {
    self.transmitCommand = commandData;
    *response = self.transmitResponseParam;
    return self.transmitResponse;
}

@end
