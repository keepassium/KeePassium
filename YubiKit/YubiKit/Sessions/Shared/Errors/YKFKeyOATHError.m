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

#import "YKFKeyOATHError.h"
#import "YKFKeySessionError+Private.h"

static NSString* const YKFKeyOATHErrorNameTooLongDescription = @"The credential has a name longer then the maximum allowed size by the key (64 bytes).";
static NSString* const YKFKeyOATHErrorSecretTooLongDescription = @"The credential has a secret longer then the size of the hash algorithm size.";
static NSString* const YKFKeyOATHErrorBadCalculationResponseDescription = @"The key returned a malformed response to the calculate request.";
static NSString* const YKFKeyOATHErrorBadListResponseDescription = @"The key returned a malformed response to the list request.";
static NSString* const YKFKeyOATHErrorBadApplicationSelectionResponseDescription = @"The key returned a malformed response when selecting OATH.";
static NSString* const YKFKeyOATHErrorAuthenticationRequiredDescription = @"Authentication required.";
static NSString* const YKFKeyOATHErrorMalformedValidationResponseDescription = @"The key returned a malformed response when validating.";
static NSString* const YKFKeyOATHErrorBadCalculateAllResponseDescription = @"The key returned a malformed response when calculating all credentials.";
static NSString* const YKFKeyOATHErrorCodeTouchTimeoutDescription = @"The key did time out, waiting for touch.";
static NSString* const YKFKeyOATHErrorCodeWrongPasswordDescription = @"Wrong password.";

@implementation YKFKeyOATHError

static NSDictionary *errorMap = nil;

+ (YKFKeySessionError *)errorWithCode:(NSUInteger)code {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [YKFKeyOATHError buildErrorMap];
    });
    
    NSString *errorDescription = errorMap[@(code)];
    if (!errorDescription) {
        return [super errorWithCode:code];
    }
    return [[YKFKeySessionError alloc] initWithCode:code message:errorDescription];
}

+ (void)buildErrorMap {
    errorMap =
    @{@(YKFKeyOATHErrorCodeNameTooLong): YKFKeyOATHErrorNameTooLongDescription,
      @(YKFKeyOATHErrorCodeSecretTooLong): YKFKeyOATHErrorSecretTooLongDescription,
      @(YKFKeyOATHErrorCodeBadCalculationResponse): YKFKeyOATHErrorBadCalculationResponseDescription,
      @(YKFKeyOATHErrorCodeBadListResponse): YKFKeyOATHErrorBadListResponseDescription,
      @(YKFKeyOATHErrorCodeBadApplicationSelectionResponse): YKFKeyOATHErrorBadApplicationSelectionResponseDescription,
      @(YKFKeyOATHErrorCodeAuthenticationRequired): YKFKeyOATHErrorAuthenticationRequiredDescription,
      @(YKFKeyOATHErrorCodeBadValidationResponse): YKFKeyOATHErrorMalformedValidationResponseDescription,
      @(YKFKeyOATHErrorCodeBadCalculateAllResponse): YKFKeyOATHErrorBadCalculateAllResponseDescription,
      @(YKFKeyOATHErrorCodeTouchTimeout): YKFKeyOATHErrorCodeTouchTimeoutDescription,
      @(YKFKeyOATHErrorCodeWrongPassword): YKFKeyOATHErrorCodeWrongPasswordDescription
      };
}

@end
