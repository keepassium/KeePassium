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

#import "YKFNSStringAdditions.h"

@implementation NSString(NSString_OATH)

- (void)ykf_OATHKeyExtractPeriod:(NSUInteger *)period issuer:(NSString **)issuer account:(NSString **)account label:(NSString **)label {
    NSString *key = self;
    
    // TOTP key with format [period]/[label]
    if ([self containsString:@"/"]) {
        NSArray *stringComponents = [self componentsSeparatedByString:@"/"];
        if (stringComponents.count == 2) {
            NSUInteger interval = [stringComponents[0] intValue];
            if (interval) {
                *period = interval;
            }
            key = stringComponents[1];
        }
    }
    
    *label = key;

    // Parse the label as [issuer]:[account]
    NSArray *labelComponents = [key componentsSeparatedByString:@":"];
    if (labelComponents.count == 2) {
        *issuer = labelComponents[0];
        *account = labelComponents[1];
    } else {
        *account = key;
    }
}

@end
