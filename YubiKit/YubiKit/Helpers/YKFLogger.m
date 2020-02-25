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

#import "YKFLogger.h"
#import "YubiKitLogger.h"

// Prefix for showing Info logs.
static NSString* const YKFLogPrefixInfo = @"►►[I]► YubiKit:";

// Prefix for showing Verbose logs.
static NSString* const YKFLogPrefixVerbose = @"►►[V]► YubiKit:";

// Prefix for showing Error logs.
static NSString* const YKFLogPrefixError = @"►►[E]► YubiKit:";

// Prefix for showing Assertions logs (helpful in Automation).
static NSString* const YKFLogPrefixAssertion = @"►►[A]► YubiKit:";

void YKFLog(NSString *format, va_list args) {
#ifdef DEBUG
    NSLogv(format, args);
#endif
    if (YubiKitLogger.customLogger) {
        NSString *message = [[NSString alloc] initWithFormat:format arguments: args];
        [YubiKitLogger.customLogger log:message];
    }
}

void YKFLogInfo(NSString* _Nonnull format, ...) {
    va_list args;
    va_start(args, format);
    
    NSString *ykFormat = [NSString stringWithFormat:@"%@ %@", YKFLogPrefixInfo, format];
    YKFLog(ykFormat, args);
    
    va_end(args);
}

void YKFLogError(NSString* _Nonnull format, ...) {
    va_list args;
    va_start(args, format);
    
    NSString *ykFormat = [NSString stringWithFormat:@"%@ %@", YKFLogPrefixError, format];
    YKFLog(ykFormat, args);
    
    va_end(args);
}

void YKFLogNSError(NSError *error) {
    NSInteger errorCode = error.code;
    NSString *errorType = NSStringFromClass(error.class);
    NSString *errorMessage = error.localizedDescription;
    
    YKFLogError(@"%@(%ld) - %@", errorType, (long)errorCode, errorMessage);
}

void YKFLogAssertion(NSString* _Nonnull format, ...) {
    va_list args;
    va_start(args, format);
    
    NSString *ykFormat = [NSString stringWithFormat:@"%@ %@", YKFLogPrefixAssertion, format];
    YKFLog(ykFormat, args);
    
    va_end(args);
}

void YKFLogVerbose(NSString* _Nonnull format, ...) {
#ifdef YKF_ENABLE_VERBOSE_LOGGING
    va_list args;
    va_start(args, format);
    
    NSString *ykFormat = [NSString stringWithFormat:@"%@ %@", YKFLogPrefixVerbose, format];
    YKFLog(ykFormat, args);
    
    va_end(args);
#endif
}
