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

#import "YKFKeyFIDO2ClientPinResponse.h"
#import "YKFCBORDEcoder.h"
#import "YKFAssert.h"

typedef NS_ENUM(NSUInteger, YKFKeyFIDO2ClientPinResponseKey) {
    YKFKeyFIDO2ClientPinResponseKeyKeyAgreement = 0x01,
    YKFKeyFIDO2ClientPinResponsePinToken        = 0x02,
    YKFKeyFIDO2ClientPinResponseKeyRetries      = 0x03
};

@interface YKFKeyFIDO2ClientPinResponse()

@property (nonatomic, readwrite) NSDictionary *keyAgreement;
@property (nonatomic, readwrite) NSData *pinToken;
@property (nonatomic, readwrite) NSUInteger retries;

@end

@implementation YKFKeyFIDO2ClientPinResponse

- (nullable instancetype)initWithCBORData:(NSData *)cborData {
    self = [super init];
    if (self) {
        YKFCBORMap *responseMap = nil;
        
        NSInputStream *decoderInputStream = [[NSInputStream alloc] initWithData:cborData];
        [decoderInputStream open];
        responseMap = [YKFCBORDecoder decodeObjectFrom:decoderInputStream];
        [decoderInputStream close];
        
        YKFAssertAbortInit(responseMap);
        
        BOOL success = [self parseResponseMap: responseMap];
        YKFAssertAbortInit(success);
    }
    return self;
}

- (BOOL)parseResponseMap:(YKFCBORMap *)map {
    id convertedObject = [YKFCBORDecoder convertCBORObjectToFoundationType:map];
    if (!convertedObject || ![convertedObject isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    NSDictionary *response = (NSDictionary *)convertedObject;
    
    self.keyAgreement = response[@(YKFKeyFIDO2ClientPinResponseKeyKeyAgreement)];
    self.pinToken = response[@(YKFKeyFIDO2ClientPinResponsePinToken)];
    
    NSNumber *retries = response[@(YKFKeyFIDO2ClientPinResponseKeyRetries)];
    if (retries != nil) {
        self.retries = retries.integerValue;
    }
    
    return YES;
}

@end
