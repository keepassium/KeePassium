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

#import "YKFOTPTextParser.h"
#import "YKFAssert.h"

static const UInt8 YKFOTPTextParserCustomPayloadType = 0x05;

@interface YKFOTPTextParser()

@property (nonatomic, nonnull) id<YKFOTPTokenValidatorProtocol> validator;

@end

@implementation YKFOTPTextParser

- (instancetype)initWithValidator:(id<YKFOTPTokenValidatorProtocol>)validator {
    YKFAssertAbortInit(validator)
    
    self = [super init];
    if (self) {
        self.validator = validator;
    }
    return self;
}

- (NSString *)tokenFromPayload:(NSString *)payload {
    YKFParameterAssertReturnValue(payload, @"")
    
    NSArray *components = [payload componentsSeparatedByString:@"/"];
    if (components.count >= 2) {
        NSString *token = components.lastObject;
        return [self.validator validateToken:token] ? token : @"";
    }
    
    // Assume the payload is the token
    return [self.validator validateToken:payload] ? payload : @"";
}

- (NSString *)textFromPayload:(NSString *)payload {
    YKFParameterAssertReturnValue(payload, nil)
        
    if([payload characterAtIndex:0] == YKFOTPTextParserCustomPayloadType) {
        // The payload contains a custom type identifier
        return [payload substringFromIndex:1];
    } else {
        return payload;
    }
}

@end
