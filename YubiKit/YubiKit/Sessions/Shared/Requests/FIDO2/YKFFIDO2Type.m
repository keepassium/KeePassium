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

#import "YKFFIDO2Type.h"
#import "YKFCBORType.h"
#import "YKFFIDO2Type+Private.h"

#pragma mark - YKFFIDO2PublicKeyCredentialRpEntity

@implementation YKFFIDO2PublicKeyCredentialRpEntity

- (id)cborTypeObject {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    YKFCBORTextString *idKey = YKFCBORTextString(@"id");
    dictionary[idKey] = YKFCBORTextString(self.rpId);
    
    if (self.rpName) {
        YKFCBORTextString *nameKey = YKFCBORTextString(@"name");
        dictionary[nameKey] = YKFCBORTextString(self.rpName);
    }
    if (self.rpIcon) {
        YKFCBORTextString *iconKey = YKFCBORTextString(@"icon");
        dictionary[iconKey] = YKFCBORTextString(self.rpIcon);
    }
    
    return YKFCBORMap([dictionary copy]);
}

@end


#pragma mark - YKFFIDO2PublicKeyCredentialUserEntity

@implementation YKFFIDO2PublicKeyCredentialUserEntity

- (id)cborTypeObject {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    YKFCBORTextString *idKey = YKFCBORTextString(@"id");
    dictionary[idKey] = YKFCBORByteString(self.userId);
    
    if (self.userName) {
        YKFCBORTextString *nameKey = YKFCBORTextString(@"name");
        dictionary[nameKey] = YKFCBORTextString(self.userName);
    }
    if (self.userDisplayName) {
        YKFCBORTextString *userDisplayNameKey = YKFCBORTextString(@"displayName");
        dictionary[userDisplayNameKey] = YKFCBORTextString(self.userDisplayName);
    }
    if (self.userIcon) {
        YKFCBORTextString *userIconKey = YKFCBORTextString(@"icon");
        dictionary[userIconKey] = YKFCBORTextString(self.userIcon);
    }
    
    return YKFCBORMap([dictionary copy]);
}

@end


#pragma mark - YKFFIDO2PublicKeyCredentialType

@implementation YKFFIDO2PublicKeyCredentialType

- (id)cborTypeObject {
    return YKFCBORTextString(self.name);
}

@end


#pragma mark - YKFFIDO2PublicKeyCredentialParam

@implementation YKFFIDO2PublicKeyCredentialParam

- (id)cborTypeObject {
    NSDictionary *dictionary = @{YKFCBORTextString(@"alg"): YKFCBORInteger(self.alg),
                                 YKFCBORTextString(@"type"): YKFCBORTextString(@"public-key")};
    return YKFCBORMap(dictionary);
}

@end


#pragma mark - YKFFIDO2AuthenticatorTransport

NSString* const YKFFIDO2AuthenticatorTransportUSB = @"usb";
NSString* const YKFFIDO2AuthenticatorTransportNFC = @"nfc";
NSString* const YKFFIDO2AuthenticatorTransportBLE = @"ble";

@implementation YKFFIDO2AuthenticatorTransport

- (id)cborTypeObject {
    return YKFCBORTextString(self.name);
}

@end


#pragma mark - YKFFIDO2PublicKeyCredentialDescriptor

@implementation YKFFIDO2PublicKeyCredentialDescriptor

- (id)cborTypeObject {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    YKFCBORTextString *idKey = YKFCBORTextString(@"id");
    dictionary[idKey] = YKFCBORByteString(self.credentialId);
    
    YKFCBORTextString *typeKey = YKFCBORTextString(@"type");
    dictionary[typeKey] = [self.credentialType cborTypeObject];

    if (self.credentialTransports) {
        YKFCBORTextString *transportsKey = YKFCBORTextString(@"transports");
        NSMutableArray *transportsArray = [[NSMutableArray alloc] initWithCapacity:self.credentialTransports.count];
        for (YKFFIDO2AuthenticatorTransport *transport in self.credentialTransports) {
            [transportsArray addObject:[transport cborTypeObject]];
        }
        dictionary[transportsKey] = YKFCBORArray([transportsArray copy]);
    }
    
    return YKFCBORMap([dictionary copy]);
}

@end
