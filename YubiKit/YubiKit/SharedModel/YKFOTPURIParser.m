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

#import "YKFOTPURIParser.h"
#import "YKFURIIdentifierCode.h"
#import "YKFAssert.h"

@interface YKFOTPURIParser()

@property (nonatomic) id<YKFOTPTokenValidatorProtocol> validator;
@property (nonatomic) YKFURIIdentifierCode *uriIdentifierCode;

@end

@implementation YKFOTPURIParser

- (instancetype)initWithValidator:(id<YKFOTPTokenValidatorProtocol>)validator {
    YKFAssertAbortInit(validator);
    
    self = [super init];
    if (self) {
        self.validator = validator;
        self.uriIdentifierCode = [[YKFURIIdentifierCode alloc] init];
    }
    return self;
}

- (NSString *)tokenFromPayload:(NSString *)payload {
    YKFParameterAssertReturnValue(payload, @"");
    
    NSString *composedURL = [self composedURIFromPayload:payload];
    NSURL *url = [[NSURL alloc] initWithString:composedURL];
    
    NSString *token = nil;
    
    if (url.pathComponents.count > 1) {
        token = [url.absoluteString lastPathComponent];
    } else {
        // Assume the payload is the token
        token = payload;
    }
    
    // Check for # on newer versions of the YubiKey. Remove it before checking for the token value.
    if ([token hasPrefix:@"#"]) {
        token = [token stringByReplacingOccurrencesOfString:@"#" withString:@""];
    }
    
    return [self.validator validateToken:token] ? token : @"";
}

- (NSString *)uriFromPayload:(NSString *)payload {
    YKFParameterAssertReturnValue(payload, nil);
    
    NSString *composedURL = [self composedURIFromPayload:payload];
    NSURL *url = [[NSURL alloc] initWithString:composedURL];
    
    if (url.pathComponents.count > 1) {
        return url.absoluteString;
    }
    return nil;
}

#pragma mark - Helpers

- (NSString *)composedURIFromPayload:(NSString *)payload {
    NSNumber *firstChar = [NSNumber numberWithChar:[payload characterAtIndex:0]];
    NSString *identifierCode = [self.uriIdentifierCode prependingStringForCode:firstChar.unsignedCharValue];
    
    if (!identifierCode) {
        return payload;
    }
    
    NSMutableString *composedString = [NSMutableString stringWithString:identifierCode];
    [composedString appendString:[payload substringFromIndex:1]]; // Append the payload without the identifier code
    
    return [composedString copy];
}

@end
