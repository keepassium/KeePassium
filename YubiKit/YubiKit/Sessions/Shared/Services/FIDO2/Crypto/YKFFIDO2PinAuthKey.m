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

#import <Security/Security.h>

#import "YKFFIDO2PinAuthKey.h"
#import "YKFCBOREncoder.h"
#import "YKFCBORDecoder.h"
#import "YKFBlockMacros.h"
#import "YKFAssert.h"

/// The key type label.
static const NSInteger YKFFIDO2PinAuthKeyCoseLabelKty = 1;

/// The curve type label.
static const NSInteger YKFFIDO2PinAuthKeyCoseLabelCrv = -1;

/// The label for the X coordinate of an EC key.
static const NSInteger YKFFIDO2PinAuthKeyCoseLabelEcX = -2;

/// The label for the Y coordinate of an EC key.
static const NSInteger YKFFIDO2PinAuthKeyCoseLabelEcY = -3;

typedef NS_ENUM(NSUInteger, YKFFIDO2PinAuthKeyCoseKeyType) {
    /// Elliptic Curve Keys with x and y coordinate.
    YKFFIDO2PinAuthKeyCoseKeyTypeEc = 2
};

typedef NS_ENUM(NSUInteger, YKFFIDO2PinAuthKeyCoseCurve) {
    /// NIST P-256 also known as secp256r1.
    YKFFIDO2PinAuthKeyCoseCurveP256 = 1
};

@interface YKFFIDO2PinAuthKey()

@property (nonatomic, readwrite) SecKeyRef publicKey;
@property (nonatomic, readwrite) SecKeyRef privateKey;

@end

@implementation YKFFIDO2PinAuthKey

- (instancetype)init {
    self = [super init];
    if (self) {
        BOOL success = [self generateECKeyPair];
        YKFAssertAbortInit(success);
    }
    return self;
}

- (instancetype)initWithCosePublicKey:(NSDictionary *)cosePublicKey {
    YKFAssertAbortInit(cosePublicKey)
    
    self = [super init];
    if (self) {
        BOOL success = [self setupFromCosePublicKey:cosePublicKey];
        YKFAssertAbortInit(success);
    }
    return self;
}

- (void)dealloc {
    if (_publicKey != NULL) {
        CFRelease(_publicKey);
    }
    if (_privateKey != NULL) {
        CFRelease(_privateKey);
    }
}

#pragma mark - COSE

- (BOOL)setupFromCosePublicKey:(NSDictionary *)coseKey {
    YKFAssertOffMainThread();
    YKFParameterAssertReturnValue(coseKey, NO);
        
    NSDictionary *coseKeyDictionary = coseKey;
    NSData *xCoordinate = coseKeyDictionary[@(YKFFIDO2PinAuthKeyCoseLabelEcX)];
    NSData *yCoordinate = coseKeyDictionary[@(YKFFIDO2PinAuthKeyCoseLabelEcY)];
    
    YKFAssertReturnValue(xCoordinate.length && yCoordinate.length, @"Could not decode authKey COSE format.", NO);
    
#ifndef __clang_analyzer__ // Suppress the self.publicKey leak false-positive warning since it will be released in dealloc.
    UInt8 uncompressedHeader = 0x04;
    NSMutableData *rawKeyData = [[NSMutableData alloc] init];
    [rawKeyData appendBytes:&uncompressedHeader length:1];
    [rawKeyData appendData:xCoordinate];
    [rawKeyData appendData:yCoordinate];
    
    NSDictionary *attributes = @{(id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
                                 (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic,
                                 (id)kSecAttrKeySizeInBits: @256};
    CFErrorRef error = NULL;
    self.publicKey = SecKeyCreateWithData((__bridge CFDataRef)rawKeyData, (__bridge CFDictionaryRef)attributes, &error);
    
    BOOL success = (error == NULL);
    if (error) {
        CFRelease(error);
        if (self.publicKey) {
            CFRelease(self.publicKey);
        }
    }
    return success;
#endif
}

- (YKFCBORMap *)cosePublicKey {
    YKFAssertReturnValue(self.publicKey, @"The authKey does not contain a public key to encode.", nil);
    
    NSArray *keyCoordinates = [self getECKeyCoordinatesFromSecKey: self.publicKey];
    YKFAssertReturnValue(keyCoordinates, @"Could not read authKey coordinates.", nil);
    
    NSDictionary *coseKeyDictionary = @{YKFCBORInteger(YKFFIDO2PinAuthKeyCoseLabelKty): YKFCBORInteger(YKFFIDO2PinAuthKeyCoseKeyTypeEc),
                                        YKFCBORInteger(YKFFIDO2PinAuthKeyCoseLabelCrv): YKFCBORInteger(YKFFIDO2PinAuthKeyCoseCurveP256),
                                        YKFCBORInteger(YKFFIDO2PinAuthKeyCoseLabelEcX): YKFCBORByteString(keyCoordinates[0]),
                                        YKFCBORInteger(YKFFIDO2PinAuthKeyCoseLabelEcY): YKFCBORByteString(keyCoordinates[1])};
    YKFCBORMap *coseKeyMap = YKFCBORMap(coseKeyDictionary);
    return coseKeyMap;
}

- (NSData *)sharedSecretWithAuthKey:(YKFFIDO2PinAuthKey *)otherKey {
    YKFAssertOffMainThread();
    YKFAssertReturnValue(self.privateKey, @"Cannot generate ECDH shared secret (missing private key).", nil);
    YKFAssertReturnValue(otherKey.publicKey, @"Cannot generate ECDH shared secret (missing public key)", nil);
    
    CFErrorRef error = NULL;
    NSDictionary *parameters = [NSDictionary dictionary];
    
    // kSecKeyAlgorithmECDHKeyExchangeStandard - Returns the unwrapped X coordinate of the ECDH result (x, y).
    CFDataRef sharedSecret = SecKeyCopyKeyExchangeResult(self.privateKey, kSecKeyAlgorithmECDHKeyExchangeStandard,
                                                         otherKey.publicKey, (__bridge CFDictionaryRef)parameters, &error);
    if (error) {
        CFRelease(error);
        if (sharedSecret) {
            CFRelease(sharedSecret);
        }
        return nil;
    }
        
    return (__bridge_transfer NSData*)sharedSecret;
}

#pragma mark - Key Generation

- (BOOL)generateECKeyPair {
    YKFAssertOffMainThread();
    
    NSMutableDictionary *privateKeyParams = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *publicKeyParams = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *keyPairParams = [[NSMutableDictionary alloc] init];
    
    // Public and private keys are not stored.
    privateKeyParams[(id)kSecAttrIsPermanent] = @NO;
    publicKeyParams[(id)kSecAttrIsPermanent] = @NO;
    
    // ECC P256
    keyPairParams[(id)kSecPrivateKeyAttrs] = privateKeyParams;
    keyPairParams[(id)kSecPublicKeyAttrs] = publicKeyParams;
    keyPairParams[(id)kSecAttrKeyType] = (id)kSecAttrKeyTypeECSECPrimeRandom;
    keyPairParams[(id)kSecAttrKeySizeInBits] = @256;
    
    SecKeyRef publicKey = NULL;
    SecKeyRef privateKey = NULL;
    OSStatus err = SecKeyGeneratePair((__bridge CFDictionaryRef)keyPairParams, &publicKey, &privateKey);

    YKFAssertReturnValue(err == errSecSuccess, @"Could not generate an EC authKey", NO);
    YKFAssertReturnValue(privateKey && publicKey, @"The authKey EC key pair was not generated.", NO);
    
    self.privateKey = privateKey;
    self.publicKey = publicKey;
    
    return YES;
}

#pragma mark - Helpers

- (NSArray *)getECKeyCoordinatesFromSecKey:(SecKeyRef)secKey {
    CFDataRef externalRepresentation = SecKeyCopyExternalRepresentation(secKey, nil);
    
    // ANSI X9.63 standard using a byte string of 04 || X || Y.
    NSData *keyData = (__bridge_transfer NSData*)externalRepresentation;
    YKFAssertReturnValue(keyData.length, @"Could not copy the authKey external representation.", nil);
    
    UInt8 *keyDataBytes = (UInt8 *)keyData.bytes;
    YKFAssertReturnValue(keyDataBytes[0] == 0x04, @"Invalid external representation of authKey.", nil);
    
    keyData = [keyData subdataWithRange:NSMakeRange(1, keyData.length - 1)];
    YKFAssertReturnValue(keyData.length && (keyData.length % 2 == 0), @"Invalid external representation of authKey.", nil);

    NSUInteger halfRange = keyData.length / 2;
    NSData *xCoordinate = [keyData subdataWithRange:NSMakeRange(0, halfRange)];
    NSData *yCoordinate = [keyData subdataWithRange:NSMakeRange(halfRange, halfRange)];
    
    return @[xCoordinate, yCoordinate];
}

@end
