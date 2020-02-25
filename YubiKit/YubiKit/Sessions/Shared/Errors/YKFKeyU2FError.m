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

#import "YKFKeyU2FError.h"
#import "YKFKeySessionError+Private.h"

static NSString* const YKFKeyU2FErrorU2FSigningUnavailableDescription = @"A sign operation was performed without registration first."
                                                                         "Register the device before authenticating with it.";

@implementation YKFKeyU2FError

static NSDictionary *errorMap = nil;

+ (YKFKeySessionError *)errorWithCode:(NSUInteger)code {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [YKFKeyU2FError buildErrorMap];
    });
    
    NSString *errorDescription = errorMap[@(code)];
    if (!errorDescription) {
        return [super errorWithCode:code];
    }
    return [[YKFKeySessionError alloc] initWithCode:code message:errorDescription];
}

+ (void)buildErrorMap {
    errorMap = @{@(YKFKeyU2FErrorCodeU2FSigningUnavailable): YKFKeyU2FErrorU2FSigningUnavailableDescription };
}

@end
