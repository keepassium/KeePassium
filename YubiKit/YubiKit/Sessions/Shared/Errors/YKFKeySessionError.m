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

#import "YKFKeySessionError.h"

NSString* const YKFKeySessionErrorDomain = @"YubiKeySessionError";

#pragma mark - Error Descriptions

static NSString* const YKFKeySessionErrorStatusErrorDescription = @"Status error returned by the key.";

static NSString* const YKFKeySessionErrorReadTimeoutDescription = @"Unable to read from key. Operation timeout.";
static NSString* const YKFKeySessionErrorWriteTimeoutDescription = @"Unable to write to the key. Operation timeout.";
static NSString* const YKFKeySessionErrorTouchTimeoutDescription = @"Operation ended. User didn't touch the key.";
static NSString* const YKFKeySessionErrorKeyBusyDescription = @"The key is busy performing another operation";
static NSString* const YKFKeySessionErrorMissingApplicationDescription = @"The requested functionality is missing or disabled in the key configuration.";

#pragma mark - YKFKeySessionError

@implementation YKFKeySessionError

static NSDictionary *errorMap = nil;

+ (YKFKeySessionError *)errorWithCode:(NSUInteger)code {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [YKFKeySessionError buildErrorMap];
    });
    
    NSString *errorDescription = errorMap[@(code)];
    if (!errorDescription) {
        errorDescription = YKFKeySessionErrorStatusErrorDescription;
    }
    
    return [[YKFKeySessionError alloc] initWithCode:code message:errorDescription];
}

+ (void)buildErrorMap {
    errorMap =
    @{@(YKFKeySessionErrorReadTimeoutCode):         YKFKeySessionErrorReadTimeoutDescription,
      @(YKFKeySessionErrorWriteTimeoutCode):        YKFKeySessionErrorWriteTimeoutDescription,
      @(YKFKeySessionErrorTouchTimeoutCode):        YKFKeySessionErrorTouchTimeoutDescription,
      @(YKFKeySessionErrorKeyBusyCode):             YKFKeySessionErrorKeyBusyDescription,
      @(YKFKeySessionErrorMissingApplicationCode):  YKFKeySessionErrorMissingApplicationDescription,            
      };
}

#pragma mark - Initializers

- (instancetype)initWithCode:(NSInteger)code message:(NSString *)message {
    return [super initWithDomain:YKFKeySessionErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end
