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

#import "YKFKeyFIDO2MakeCredentialResponse.h"
#import "YKFKeyFIDO2MakeCredentialResponse+Private.h"
#import "YKFCBORDecoder.h"
#import "YKFCBOREncoder.h"
#import "YKFAssert.h"

typedef NS_ENUM(NSUInteger, YKFKeyFIDO2MakeCredentialResponseKey) {
    YKFKeyFIDO2GetInfoResponseKeyFmt        = 0x01,
    YKFKeyFIDO2GetInfoResponseKeyAuthData   = 0x02,
    YKFKeyFIDO2GetInfoResponseKeyAttStmt    = 0x03
};

typedef NS_ENUM(NSUInteger, YKFFIDO2AuthenticatorDataFlag) {
    YKFFIDO2AuthenticatorDataFlagUserPresent    = 0x01,
    YKFFIDO2AuthenticatorDataFlagUserVerified   = 0x04,
    YKFFIDO2AuthenticatorDataFlagAttested       = 0x40,
    YKFFIDO2AuthenticatorDataFlagExtensionData  = 0x80
};

static NSString* const YKFKeyFIDO2MakeCredentialResponsePackedAttStmtFmt = @"packed";

@interface YKFFIDO2AuthenticatorData()

@property (nonatomic, readwrite) NSData *rpIdHash;
@property (nonatomic, readwrite) UInt8 flags;
@property (nonatomic, readwrite) UInt32 signCount;
@property (nonatomic, readwrite) NSData *aaguid;
@property (nonatomic, readwrite) NSData *credentialId;
@property (nonatomic, readwrite) NSData *coseEncodedCredentialPublicKey;

- (instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;

@end

@interface YKFKeyFIDO2MakeCredentialResponse()

@property (nonatomic, readwrite) NSData *authData;
@property (nonatomic, readwrite) NSString *fmt;
@property (nonatomic, readwrite) NSData *attStmt;

@property (nonatomic, readwrite) NSData *rawResponse;

@property (nonatomic, readwrite) NSData *ctapAttestationObject;
@property (nonatomic, readwrite) NSData *webauthnAttestationObject;

@end

@implementation YKFKeyFIDO2MakeCredentialResponse

- (instancetype)initWithCBORData:(NSData *)cborData {
    self = [super init];
    if (self) {
        YKFAssertAbortInit(cborData);
        
        self.rawResponse = cborData;
        self.ctapAttestationObject = cborData;
        
        YKFCBORMap *attestationMap = nil;
        
        NSInputStream *decoderInputStream = [[NSInputStream alloc] initWithData:cborData];
        [decoderInputStream open];
        attestationMap = [YKFCBORDecoder decodeObjectFrom:decoderInputStream];
        [decoderInputStream close];
        
        YKFAssertAbortInit(attestationMap);
        
        BOOL success = [self parseAttestationMap: attestationMap];
        YKFAssertAbortInit(success);
        
        success = [self buildWebAuthnAttestationObjectFromMap:attestationMap];
        YKFAssertAbortInit(success);
    }
    return self;
}

- (BOOL)parseAttestationMap:(YKFCBORMap *)map {
    id convertedObject = [YKFCBORDecoder convertCBORObjectToFoundationType:map];
    if (!convertedObject || ![convertedObject isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    NSDictionary *response = (NSDictionary *)convertedObject;
    
    // Auth Data
    NSData *authData = response[@(YKFKeyFIDO2GetInfoResponseKeyAuthData)];
    YKFAssertReturnValue(authData, @"authenticatorMakeCredential authData is required.", NO);
    self.authData = authData;

    // Fmt
    NSString *fmt = response[@(YKFKeyFIDO2GetInfoResponseKeyFmt)];
    YKFAssertReturnValue(fmt, @"authenticatorMakeCredential fmt is required.", NO);
    self.fmt = fmt;

    // AttStmt
    if ([fmt isEqualToString:YKFKeyFIDO2MakeCredentialResponsePackedAttStmtFmt]) {
        YKFCBORMap *attStmtMap = map.value[YKFCBORInteger(YKFKeyFIDO2GetInfoResponseKeyAttStmt)];
        self.attStmt = [YKFCBOREncoder encodeMap:attStmtMap];
    } else {
        self.attStmt = response[@(YKFKeyFIDO2GetInfoResponseKeyAttStmt)];
    }
    YKFAssertReturnValue(self.attStmt, @"authenticatorGetInfo attStmt is required.", NO);

    return YES;
}

- (BOOL)buildWebAuthnAttestationObjectFromMap:(YKFCBORMap *)map {
    id authData = map.value[YKFCBORInteger(YKFKeyFIDO2GetInfoResponseKeyAuthData)];
    YKFAssertReturnValue(authData, @"authenticatorGetInfo authData is required.", NO);
    
    id fmt = map.value[YKFCBORInteger(YKFKeyFIDO2GetInfoResponseKeyFmt)];
    YKFAssertReturnValue(fmt, @"authenticatorGetInfo fmt is required.", NO);
    
    id attStmt = map.value[YKFCBORInteger(YKFKeyFIDO2GetInfoResponseKeyAttStmt)];
    YKFAssertReturnValue(attStmt, @"authenticatorGetInfo attStmt is required.", NO);
    
    NSDictionary *attestationDictionary = @{YKFCBORTextString(@"authData"): authData,
                                            YKFCBORTextString(@"fmt"): fmt,
                                            YKFCBORTextString(@"attStmt"): attStmt};
    YKFCBORMap *attestationMap = YKFCBORMap(attestationDictionary);
    NSData *cborEncodedAttestationMap = [YKFCBOREncoder encodeMap:attestationMap];
    self.webauthnAttestationObject = cborEncodedAttestationMap;
    
    return cborEncodedAttestationMap != nil;
}

#pragma mark - Derived Properties

- (YKFFIDO2AuthenticatorData *)authenticatorData {
    return [[YKFFIDO2AuthenticatorData alloc] initWithData:self.authData];
}

@end

@implementation YKFFIDO2AuthenticatorData

- (instancetype)initWithData:(NSData *)data {
    YKFAssertAbortInit(data.length >= 37) // SHA(32) + Flags(1) + Counter(4)
    
    self = [super init];
    if (self) {
        self.rpIdHash = [data subdataWithRange:NSMakeRange(0, 32)];
        
        UInt8 *dataBytes = (UInt8 *)data.bytes;
        self.flags = dataBytes[32];
        
        UInt32 bigEndianSignCount = *((UInt32 *)(&dataBytes[33]));
        self.signCount = CFSwapInt32BigToHost(bigEndianSignCount);
        
        if (self.flags & YKFFIDO2AuthenticatorDataFlagAttested) {
            NSUInteger attestedCredentialDataOffset = 37;
            
            NSData *attestedCredentialData = [data subdataWithRange:NSMakeRange(attestedCredentialDataOffset, data.length - attestedCredentialDataOffset)];
            YKFAssertAbortInit(attestedCredentialData.length >= 18); // AAGUID(16) + CredentialIdLength(2)
            
            self.aaguid = [attestedCredentialData subdataWithRange:NSMakeRange(0, 16)];
            
            UInt8 *attestedCredentialDataBytes = (UInt8 *)attestedCredentialData.bytes;
            UInt16 bigEndianCredentialIdLength = *((UInt16 *)(&attestedCredentialDataBytes[16]));
            UInt16 credentialIdLength = CFSwapInt16BigToHost(bigEndianCredentialIdLength);
            
            if (credentialIdLength > 0) {
                NSUInteger coseKeyOffset = 18 + credentialIdLength;
                
                YKFAssertAbortInit(attestedCredentialData.length > coseKeyOffset);
                self.credentialId = [attestedCredentialData subdataWithRange:NSMakeRange(18, credentialIdLength)];
                
                NSRange coseKeyRange = NSMakeRange(coseKeyOffset, attestedCredentialData.length - coseKeyOffset);
                self.coseEncodedCredentialPublicKey = [attestedCredentialData subdataWithRange: coseKeyRange];
                YKFAssertAbortInit(self.coseEncodedCredentialPublicKey.length > 0);
            }
        }
    }
    return self;
}

@end
