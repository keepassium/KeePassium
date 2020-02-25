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

#import "YKFKeyU2FSignRequest.h"
#import "YKFU2FSignAPDU.h"
#import "YKFAssert.h"
#import "YKFKeyU2FRequest+Private.h"

/*
 DOMString typ as defined in FIDO U2F Raw Message Format
 https://fidoalliance.org/specs/u2f-specs-1.0-bt-nfc-id-amendment/fido-u2f-raw-message-formats.html
 */
static NSString* const U2FClientDataTypeAuthentication = @"navigator.id.getAssertion";

/*
 Client data as defined in FIDO U2F Raw Message Format
 https://fidoalliance.org/specs/u2f-specs-1.0-bt-nfc-id-amendment/fido-u2f-raw-message-formats.html
 Note: The "cid_pubkey" is missing in this case since the TLS stack on iOS does not support channel id.
 */
static NSString* const U2FClientDataTypeTemplate = @"\{\"typ\":\"%@\",\"challenge\":\"%@\",\"origin\":\"%@\"}";

@interface YKFKeyU2FSignRequest()

@property (nonatomic, readwrite) NSString *challenge;
@property (nonatomic, readwrite) NSString *keyHandle;
@property (nonatomic, readwrite) NSString *appId;

@end

@implementation YKFKeyU2FSignRequest

- (instancetype)initWithChallenge:(NSString *)challenge keyHandle:(NSString *)keyHandle appId:(NSString *)appId {
    YKFAssertAbortInit(challenge);
    YKFAssertAbortInit(keyHandle);
    YKFAssertAbortInit(appId);
    
    self = [super init];
    if (self) {
        self.challenge = challenge;
        self.keyHandle = keyHandle;        
        self.appId = appId;        
        self.clientData = [[NSString alloc] initWithFormat:U2FClientDataTypeTemplate, U2FClientDataTypeAuthentication, self.challenge, self.appId];
        
        self.apdu = [[YKFU2FSignAPDU alloc] initWithU2fSignRequest:self];
    }
    return self;
}

@end
