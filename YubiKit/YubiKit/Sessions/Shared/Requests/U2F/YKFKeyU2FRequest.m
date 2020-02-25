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

#import "YKFKeyU2FRequest.h"
#import "YKFKeyU2FRequest+Private.h"

static const int YKFKeyU2FRequestMaxRetries = 30; // times
static const NSTimeInterval YKFKeyU2FRequestRetryTimeInterval = 0.5; // seconds

@implementation YKFKeyU2FRequest

- (BOOL)shouldRetry {
    return self.retries <= YKFKeyU2FRequestMaxRetries;
}

- (NSTimeInterval)retryTimeInterval {
    return YKFKeyU2FRequestRetryTimeInterval;
}

@end
