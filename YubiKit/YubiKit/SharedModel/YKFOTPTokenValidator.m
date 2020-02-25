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

#import "YKFOTPTokenValidator.h"

typedef NS_ENUM(NSUInteger, YKFOTPTokenValidatorTokenLength) {
    YKFOTPTokenValidatorTokenLengthDefaultYubicoOTP = 44,
    YKFOTPTokenValidatorTokenMinLengthYubicoOTP = 32,
    YKFOTPTokenValidatorTokenMaxLengthYubicoOTP = 64,
    
    YKFOTPTokenValidatorTokenHOTPShort = 6,
    YKFOTPTokenValidatorTokenHOTPLong = 8
};

@interface YKFOTPTokenValidator()

@property (nonatomic, strong) NSCharacterSet *notNumbersCharacterSet;
@property (nonatomic, strong) NSCharacterSet *notModhexCharacterSet;

@end

@implementation YKFOTPTokenValidator

- (instancetype)init {
    self = [super init];
    if (self) {
        self.notNumbersCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] invertedSet];
        // Modhex mapping: https://developers.yubico.com/yubico-c/Manuals/modhex.1.html
        self.notModhexCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"cbdefghijklnrtuv"] invertedSet];
    }
    return self;
}

#pragma mark - Validation

- (BOOL)maybeHOTP:(NSString *)token {
    if (token.length < YKFOTPTokenValidatorTokenHOTPShort) {
        return NO;
    }
    
    NSString *actualToken = nil;
    
    // Try long
    if (token.length >= YKFOTPTokenValidatorTokenHOTPLong) {
        NSUInteger index = token.length - YKFOTPTokenValidatorTokenHOTPLong;
        actualToken = [token substringFromIndex:index];
        
        // Try short
        if (![self tokenIsDecimalNumber:actualToken]) {
            NSUInteger index = token.length - YKFOTPTokenValidatorTokenHOTPShort;
            actualToken = [token substringFromIndex:index];
        }
    // Try short
    } else {
        NSUInteger index = token.length - YKFOTPTokenValidatorTokenHOTPShort;
        actualToken = [token substringFromIndex:index];
    }
    
    return [self tokenIsDecimalNumber:actualToken];
}

- (BOOL)maybeYubicoOTP:(NSString *)token {
    int minLength = YKFOTPTokenValidatorTokenMinLengthYubicoOTP;
    int maxLength = YKFOTPTokenValidatorTokenMaxLengthYubicoOTP;
    
    BOOL tokenIsInSizeRange = token.length >= minLength && token.length <= maxLength;
    BOOL tokenIsModhexEncoded = [token rangeOfCharacterFromSet:self.notModhexCharacterSet].location == NSNotFound;
    
    return tokenIsInSizeRange && tokenIsModhexEncoded;
}

- (BOOL)validateToken:(NSString *)token {
    return [self maybeYubicoOTP:token] || [self maybeHOTP:token];
}

#pragma mark - Helpers

- (BOOL)tokenIsDecimalNumber:(NSString *)token {
    if (!token.length) {
        return NO;
    }
    if ([token rangeOfCharacterFromSet:self.notNumbersCharacterSet].location != NSNotFound) {
        return NO;
    }
    return [token intValue] != 0;
}

@end
