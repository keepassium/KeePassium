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

#import "YKFKeyOATHValidateResponse.h"
#import "YKFAssert.h"
#import "YKFNSDataAdditions+Private.h"

static const UInt8 YKFKeyOATHValidateResponseTag = 0x75;

@interface YKFKeyOATHValidateResponse()

@property (nonatomic, readwrite, nonnull) NSData *response;

@end

@implementation YKFKeyOATHValidateResponse

- (instancetype)initWithResponseData:(NSData *)responseData {
    YKFAssertAbortInit(responseData.length);
    
    self = [super init];
    if (self) {
        UInt8 *bytes = (UInt8 *)responseData.bytes;
        NSUInteger readIndex = 0;
        
        UInt8 responseTag = bytes[readIndex];
        YKFAssertAbortInit(responseTag == YKFKeyOATHValidateResponseTag);
        
        ++readIndex;
        YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
        
        UInt8 responseLength = bytes[readIndex];
        YKFAssertAbortInit(responseLength > 0);
        
        ++readIndex;
        NSRange responseRange = NSMakeRange(readIndex, responseLength);
        YKFAssertAbortInit([responseData ykf_containsRange:responseRange]);
        self.response = [responseData subdataWithRange:responseRange];
    }
    return self;
}

@end
