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

#import "YKFWebAuthnClientData.h"
#import "YKFNSDataAdditions.h"
#import "YKFAssert.h"

@interface YKFWebAuthnClientData()

@property (nonatomic, readwrite) YKFWebAuthnClientDataType type;
@property (nonatomic, readwrite) NSData *challenge;
@property (nonatomic, readwrite) NSString *origin;

@end

@implementation YKFWebAuthnClientData

- (NSData *)jsonData {
    NSString *websafeChallenge = self.challenge.ykf_websafeBase64EncodedString;
    YKFAssertReturnValue(websafeChallenge, @"Could not websafeBase64 encode the challenge data.", nil);
    
    NSString *webauthnType = nil;
    switch (self.type) {
        case YKFWebAuthnClientDataTypeCreate:
            webauthnType = @"webauthn.create";
            break;
        case YKFWebAuthnClientDataTypeGet:
            webauthnType = @"webauthn.get";
    }
    YKFAssertReturnValue(webauthnType, @"Invalid WebAuthN method type.", nil);
    
    NSDictionary *jsonDictionary = @{@"type": webauthnType,
                                     @"challenge": websafeChallenge,
                                     @"origin": self.origin};
    NSError *error = nil;
    NSData *result = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:&error];
    YKFAssertReturnValue(!error && result, @"Could not serialize the clientDataJson.", nil);
    
    return result;
}

- (NSData *)clientDataHash {
    NSData *clientData = self.jsonData;
    YKFAssertReturnValue(clientData, @"Invalid WebAuthN client data JSON.", nil);
    
    return clientData.ykf_SHA256;
}

- (nullable instancetype)initWithType:(YKFWebAuthnClientDataType)type challenge:(NSData *)challenge origin:(NSString *)origin {
    YKFAssertAbortInit(challenge);
    YKFAssertAbortInit(origin);
    
    self = [super init];
    if (self) {
        self.type = type;
        self.challenge = challenge;
        self.origin = origin;
    }
    return self;
}

@end
