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

#import "YKFKeyOATHListResponse.h"
#import "YKFKeyOATHListResponse+Private.h"
#import "YKFOATHCredential.h"
#import "YKFOATHCredential+Private.h"
#import "YKFAssert.h"
#import "YKFNSStringAdditions.h"
#import "YKFNSDataAdditions+Private.h"

static const int YKFKeyOATHListResponseNameTag = 0x72;

@interface YKFKeyOATHListResponse()

@property (nonatomic, readwrite) NSArray *credentials;

@end

@implementation YKFKeyOATHListResponse

- (nullable instancetype)initWithKeyResponseData:(NSData *)responseData {
    YKFAssertAbortInit(responseData);
    
    self = [super init];
    if (self) {
        BOOL success = [self readCredentialsFromData:responseData];        
        YKFAbortInitWhen(!success)
    }
    return self;
}

- (BOOL)readCredentialsFromData:(NSData *)data {
    if (!data.length) {
        self.credentials = [[NSArray alloc] init];
        return YES;
    }
    
    NSUInteger readIndex = 0;
    UInt8 *bytes = (UInt8 *)data.bytes;
    NSMutableArray *parsedCredentials = [[NSMutableArray alloc] init];

    while (readIndex < data.length && bytes[readIndex] == YKFKeyOATHListResponseNameTag) {
        YKFOATHCredential *credential = [[YKFOATHCredential alloc] init];
        
        ++readIndex;
        if (![data ykf_containsIndex:readIndex]) {
            return NO;
        }
        
        UInt8 nameLength = bytes[readIndex];
        if (nameLength < 1) {
            return NO; // Malformed response length
        }
        
        ++readIndex;
        if (![data ykf_containsIndex:readIndex]) {
            return NO;
        }
        
        UInt8 type = bytes[readIndex];
        
        if (type & YKFOATHCredentialTypeHOTP) {
            credential.type = YKFOATHCredentialTypeHOTP;
        } else if (type & YKFOATHCredentialTypeTOTP) {
            credential.type = YKFOATHCredentialTypeTOTP;
        } else {
            return NO; // Malformed response otp type
        }
        
        if (type & YKFOATHCredentialAlgorithmSHA1) {
            credential.algorithm = YKFOATHCredentialAlgorithmSHA1;
        } else if (type & YKFOATHCredentialAlgorithmSHA256) {
            credential.algorithm = YKFOATHCredentialAlgorithmSHA256;
        } else if (type & YKFOATHCredentialAlgorithmSHA512) {
            credential.algorithm = YKFOATHCredentialAlgorithmSHA512;
        } else {
            return NO; // Malformed response algorithm
        }
        
        ++readIndex;
        if (![data ykf_containsIndex:readIndex]) {
            return NO;
        }
        
        UInt8 keyLength = nameLength - 1;
        NSRange keyRange = NSMakeRange(readIndex, keyLength);
        if (![data ykf_containsRange:keyRange]) {
            return NO;
        }
        
        NSData *key = [data subdataWithRange:keyRange];
        NSString *keyString = [[NSString alloc] initWithData:key encoding:NSUTF8StringEncoding];
        credential.key = keyString;
        
        // Parse the period, account and issuer from the key.
        
        NSUInteger period = 0;
        NSString *issuer = nil;
        NSString *account = nil;
        NSString *label = nil;
        
        [keyString ykf_OATHKeyExtractPeriod:&period issuer:&issuer account:&account label:&label];
        credential.period = period;
        credential.issuer = issuer;
        credential.account = account;
        credential.label = label;
        
        [parsedCredentials addObject:credential];
        
        readIndex += keyLength;
    }
    
    self.credentials = [parsedCredentials copy];
    
    return YES;
}

@end
