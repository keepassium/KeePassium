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

#import "YKFKeyFIDO2GetInfoResponse.h"
#import "YKFKeyFIDO2GetInfoResponse+Private.h"
#import "YKFCBORDecoder.h"
#import "YKFAssert.h"

NSString* const YKFKeyFIDO2GetInfoResponseOptionClientPin = @"clientPin";
NSString* const YKFKeyFIDO2GetInfoResponseOptionPlatformDevice = @"plat";
NSString* const YKFKeyFIDO2GetInfoResponseOptionResidentKey = @"rk";
NSString* const YKFKeyFIDO2GetInfoResponseOptionUserPresence = @"up";
NSString* const YKFKeyFIDO2GetInfoResponseOptionUserVerification = @"uv";

typedef NS_ENUM(NSUInteger, YKFKeyFIDO2GetInfoResponseKey) {
    YKFKeyFIDO2GetInfoResponseKeyVersions       = 0x01,
    YKFKeyFIDO2GetInfoResponseKeyExtensions     = 0x02,
    YKFKeyFIDO2GetInfoResponseKeyAAGUID         = 0x03,
    YKFKeyFIDO2GetInfoResponseKeyOptions        = 0x04,
    YKFKeyFIDO2GetInfoResponseKeyMaxMsgSize     = 0x05,
    YKFKeyFIDO2GetInfoResponseKeyPinProtocols   = 0x06
};

@interface YKFKeyFIDO2GetInfoResponse()

@property (nonatomic, readwrite) NSArray *versions;
@property (nonatomic, readwrite) NSArray *extensions;
@property (nonatomic, readwrite) NSData *aaguid;
@property (nonatomic, readwrite) NSDictionary *options;
@property (nonatomic, assign, readwrite) NSUInteger maxMsgSize;
@property (nonatomic, readwrite) NSArray *pinProtocols;

@end

@implementation YKFKeyFIDO2GetInfoResponse

- (instancetype)initWithCBORData:(NSData *)cborData {
    self = [super init];
    if (self) {
        YKFCBORMap *getInfoMap = nil;
        
        NSInputStream *decoderInputStream = [[NSInputStream alloc] initWithData:cborData];
        [decoderInputStream open];
        getInfoMap = [YKFCBORDecoder decodeObjectFrom:decoderInputStream];
        [decoderInputStream close];
        
        YKFAssertAbortInit(getInfoMap);
        
        BOOL success = [self parseResponseMap:getInfoMap];
        YKFAssertAbortInit(success);
    }
    return self;
}

#pragma mark - Private

- (BOOL)parseResponseMap:(YKFCBORMap *)map {
    id convertedObject = [YKFCBORDecoder convertCBORObjectToFoundationType:map];
    if (!convertedObject || ![convertedObject isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    NSDictionary *response = (NSDictionary *)convertedObject;
    
    // versions
    NSArray *versions = response[@(YKFKeyFIDO2GetInfoResponseKeyVersions)];
    YKFAssertReturnValue(versions, @"authenticatorGetInfo versions is required.", NO);
    self.versions = versions;
    
    // extensions
    self.extensions = response[@(YKFKeyFIDO2GetInfoResponseKeyExtensions)];
    
    // aaguid
    NSData *aaguid = response[@(YKFKeyFIDO2GetInfoResponseKeyAAGUID)];
    YKFAssertReturnValue(aaguid, @"authenticatorGetInfo aaguid is required.", NO);
    YKFAssertReturnValue(aaguid.length == 16, @"authenticatorGetInfo aaguid has the wrong value.", NO);
    self.aaguid = aaguid;
    
    // options
    self.options = response[@(YKFKeyFIDO2GetInfoResponseKeyOptions)];
    
    // maxMsgSize
    NSNumber *maxMsgSize = response[@(YKFKeyFIDO2GetInfoResponseKeyMaxMsgSize)];
    if (maxMsgSize != nil) {
        self.maxMsgSize = maxMsgSize.integerValue;
    }
    
    // pin protocols
    self.pinProtocols = response[@(YKFKeyFIDO2GetInfoResponseKeyPinProtocols)];
        
    return YES;
}

@end
