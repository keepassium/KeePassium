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
#import "YKFNSDataAdditions.h"
#import "YKFNSDataAdditions+Private.h"
#import "MF_Base32Additions.h"

#pragma mark - SHA

@implementation NSData(NSData_SHAAdditions)

- (NSData *)ykf_SHA1 {
    UInt8 digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1((const void *)[self bytes], (CC_LONG)[self length], digest);
    return [[NSData alloc] initWithBytes:(const void *)digest length:CC_SHA1_DIGEST_LENGTH];
}

- (NSData *)ykf_SHA256 {
	UInt8 digest[CC_SHA256_DIGEST_LENGTH];
	CC_SHA256((const void *)[self bytes], (CC_LONG)[self length], digest);
	return [[NSData alloc] initWithBytes:(const void *)digest length:CC_SHA256_DIGEST_LENGTH];
}

- (NSData *)ykf_SHA512 {
    UInt8 digest[CC_SHA512_DIGEST_LENGTH];
    CC_SHA512((const void *)[self bytes], (CC_LONG)[self length], digest);
    return [[NSData alloc] initWithBytes:(const void *)digest length:CC_SHA512_DIGEST_LENGTH];
}

@end

#pragma mark - OATH

@implementation NSData(NSData_OATHAdditions)

- (NSData *)ykf_deriveOATHKeyWithSalt:(NSData *)salt {
    if (!salt.length) {
        return nil;
    }
    
    UInt8 keyLength = 16; // use only 16 bytes
    UInt8 key[keyLength];
    CCKeyDerivationPBKDF(kCCPBKDF2, self.bytes, self.length, salt.bytes, salt.length, kCCPRFHmacAlgSHA1, 1000, key, keyLength);
    return [NSData dataWithBytes:key length:keyLength];
}

- (NSData *)ykf_oathHMACWithKey:(NSData *)key {
    if (!key.length) {
        return nil;
    }
    
    UInt8 *keyBytes = (UInt8 *)key.bytes;
    UInt8 *dataBytes = (UInt8 *)self.bytes;
    
    UInt8 result[CC_SHA1_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA1, keyBytes, key.length, dataBytes, self.length, result);
    
    return [[NSData alloc] initWithBytes:result length:CC_SHA1_DIGEST_LENGTH];
}

- (NSString *)ykf_parseOATHOTPFromIndex:(NSUInteger)index digits:(UInt8)digits {
    if (index + sizeof(UInt32) > self.length) {
        return nil;
    }
    
    UInt32 otpResponseValue = CFSwapInt32BigToHost(*((UInt32 *)&self.bytes[index]));
    otpResponseValue &= 0x7FFFFFFF; // remove first bit (sign bit)
    
    UInt32 modMask = pow(10, digits); // get last [digits] only
    otpResponseValue = otpResponseValue % modMask;
    
    NSString *otp = nil;
    
    // Format with 0 paddigs up to [digits] number
    if (digits == 6) {
        otp = [NSString stringWithFormat:@"%06d", (unsigned int)otpResponseValue];
    } else if (digits == 7){
        otp = [NSString stringWithFormat:@"%07d", (unsigned int)otpResponseValue];
    } else if (digits == 8){
        otp = [NSString stringWithFormat:@"%08d", (unsigned int)otpResponseValue];
    } else {
        return nil;
    }
    
    return otp;
}

@end

#pragma mark - FIDO2

@implementation NSData (NSDATA_FIDO2Additions)

- (NSData *)ykf_fido2HMACWithKey:(NSData *)key {
    if (!key.length) {
        return nil;
    }
    
    UInt8 *keyBytes = (UInt8 *)key.bytes;
    UInt8 *dataBytes = (UInt8 *)self.bytes;
    
    UInt8 result[CC_SHA256_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA256, keyBytes, key.length, dataBytes, self.length, result);
    
    return [[NSData alloc] initWithBytes:result length:CC_SHA256_DIGEST_LENGTH];
}

- (NSData *)ykf_aes256EncryptedDataWithKey:(NSData *)key {
    return [self ykf_aes256Operation:kCCEncrypt withKey:key];
}

- (NSData *)ykf_aes256DecryptedDataWithKey:(NSData *)key {
    return [self ykf_aes256Operation:kCCDecrypt withKey:key];
}

- (NSData *)ykf_aes256Operation:(CCOperation)operation withKey:(NSData *)key {
    if (!key.length) {
        return nil;
    }
    
    size_t outLength;
    NSMutableData *outData = [NSMutableData dataWithLength:self.length + kCCBlockSizeAES128];
    
    CCCryptorRef ccRef = NULL;
    CCCryptorCreate(operation, kCCAlgorithmAES, 0, key.bytes, kCCKeySizeAES256, NULL, &ccRef);
    if (!ccRef) {
        return nil;
    }
    CCCryptorStatus cryptStatus = CCCryptorUpdate(ccRef, self.bytes, self.length, outData.mutableBytes, outData.length, &outLength);
    CCCryptorRelease(ccRef);
    
    if(cryptStatus == kCCSuccess) {
        outData.length = outLength;
        return outData;
    }
    return nil;
}

- (NSData *)ykf_fido2PaddedPinData {
    if (!self.length) {
        return nil;
    }
    if (self.length == 64) {
        return self;
    }
    if ((self.length > 64) && (self.length % 16 == 0)) {
        return self;
    }
    
    NSMutableData *mutableData = [[NSMutableData alloc] initWithData:self];
    NSUInteger lengthToIncrease = 0;
    if (self.length < 64) {
        lengthToIncrease = 64 - self.length;
    } else {
        lengthToIncrease = 16 - self.length % 16;
    }
    
    if (lengthToIncrease) {
        [mutableData increaseLengthBy:lengthToIncrease];
    }
    
    return [mutableData copy];
}

@end

#pragma mark - Marshalling

@implementation NSData(NSData_Marshalling)

- (NSUInteger)ykf_getBigEndianIntegerInRange:(NSRange)range {
    NSInteger numberOfBytes = range.length;
    if (numberOfBytes>sizeof(NSUInteger)) {
        numberOfBytes = sizeof(NSUInteger);
    }
    Byte buffer[numberOfBytes];
    [self getBytes:buffer range:NSMakeRange(range.location, numberOfBytes)];
    NSUInteger value = 0;
    for(NSInteger i = 0; i < numberOfBytes; ++i){
        value = (value<<8) | buffer[i];
    }
    return value;
}

@end

#pragma mark - WebSafe Base64

@implementation NSData(NSData_WebSafeBase64)

- (instancetype)ykf_initWithWebsafeBase64EncodedString:(NSString *)websafeBase64EncodedData dataLength:(NSUInteger)dataLen {
    if (!websafeBase64EncodedData) {
        return nil;
    }
    NSMutableString *base64EncodedString = [[NSMutableString alloc] initWithString:websafeBase64EncodedData];
    [base64EncodedString replaceOccurrencesOfString:@"-" withString:@"+" options:0 range:NSMakeRange(0, [base64EncodedString length])];
    [base64EncodedString replaceOccurrencesOfString:@"_" withString:@"/" options:0 range:NSMakeRange(0, [base64EncodedString length])];
    if ((dataLen % 3) == 1){
        [base64EncodedString appendString:@"=="];
    }
    else if ((dataLen % 3) == 2) {
        [base64EncodedString appendString:@"="];
    }
    return [self initWithBase64EncodedString:base64EncodedString options:0];
}

- (NSString *)ykf_websafeBase64EncodedString {
    NSMutableString *base64 = [[NSMutableString alloc] initWithString:[self base64EncodedStringWithOptions:0]];
    [base64 replaceOccurrencesOfString:@"+" withString:@"-" options:0 range:NSMakeRange(0, [base64 length])];
    [base64 replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, [base64 length])];
    [base64 replaceOccurrencesOfString:@"=" withString:@"" options:0 range:NSMakeRange(0, [base64 length])];
    
    return [NSString stringWithString:base64];
}

@end

#pragma mark - Size Check

@implementation NSData(NSDATA_SizeCheckAdditions)

- (BOOL)ykf_containsIndex:(NSUInteger) index {
    return index < self.length;
}

- (BOOL)ykf_containsRange:(NSRange) range {
    return range.location + range.length <= self.length;
}

@end

#pragma mark - Base32

@implementation NSData(NSData_Base32Additions)

+ (NSData *)ykf_dataWithBase32String:(NSString *)base32String {
    return [self dataWithBase32String:base32String];
}

@end
