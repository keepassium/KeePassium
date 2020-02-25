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

#import "YKFNFCError.h"
#import "YKFNFCError+Errors.h"

NSString* const YKFNFCErrorDomain = @"YKFNFCError";

int const YKFNFCReadErrorNoTokenAfterScanCode = 1;
NSString* const YKFNFCReadErrorNoTokenAfterScanDescription = @"NFC scan succeeded but no OTP tokens could be detected. Please try again with a compatible key.";

@implementation YKFNFCError

+ (YKFNFCError *)noTokenAfterScanError {
    return [[YKFNFCError alloc] initWithCode:YKFNFCReadErrorNoTokenAfterScanCode
                                     description:YKFNFCReadErrorNoTokenAfterScanDescription];
}

- (instancetype)initWithCode:(int)code description:(NSString *)description {
    return [super initWithDomain:YKFNFCErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description}];
}

@end
