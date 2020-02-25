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

#import "YKFKeyOATHCalculateAllResponse.h"
#import "YKFKeyOATHCalculateAllResponse+Private.h"
#import "YKFAssert.h"
#import "YKFNSStringAdditions.h"
#import "YKFNSDataAdditions+Private.h"

static const UInt8 YKFKeyOATHCalculateAllNameTag = 0x71;
static const UInt8 YKFKeyOATHCalculateAllResponseHOTPTag = 0x77;
static const UInt8 YKFKeyOATHCalculateAllResponseFullResponseTag = 0x75;
static const UInt8 YKFKeyOATHCalculateAllResponseTruncatedResponseTag = 0x76;
static const UInt8 YKFKeyOATHCalculateAllResponseTouchTag = 0x7C;

static NSUInteger const YKFOATHCredentialCalculateResultDefaultPeriod = 30; // seconds

@interface YKFOATHCredentialCalculateResult()

@property (nonatomic, assign, readwrite) YKFOATHCredentialType type;
@property (nonatomic, readwrite) NSString *account;
@property (nonatomic, readwrite) NSString *issuer;
@property (nonatomic, assign, readwrite) NSUInteger period;
@property (nonatomic, readwrite, nonnull) NSDateInterval *validity;
@property (nonatomic, readwrite) NSString *otp;
@property (nonatomic, readwrite) BOOL requiresTouch;

@end

@implementation YKFOATHCredentialCalculateResult

- (NSUInteger)period {
    if (_period) {
        return _period;
    }
    return self.type == YKFOATHCredentialTypeTOTP ? YKFOATHCredentialCalculateResultDefaultPeriod : 0;
}

@end


@interface YKFKeyOATHCalculateAllResponse()

@property (nonatomic, readwrite) NSArray *credentials;

@end

@implementation YKFKeyOATHCalculateAllResponse

- (instancetype)initWithKeyResponseData:(NSData *)responseData requestTimetamp:(NSDate *)timestamp {
    YKFAssertAbortInit(responseData);
    
    self = [super init];
    if (self) {
        NSMutableArray *responseCredentials = [[NSMutableArray alloc] init];
        UInt8 *responseBytes = (UInt8 *)responseData.bytes;
        NSUInteger readIndex = 0;
        
        while (readIndex < responseData.length && responseBytes[readIndex] == YKFKeyOATHCalculateAllNameTag) {
            YKFOATHCredentialCalculateResult *credentialResult = [[YKFOATHCredentialCalculateResult alloc] init];
            
            ++readIndex;
            YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
            
            UInt8 nameLength = responseBytes[readIndex];
            YKFAssertAbortInit(nameLength > 0);
            
            ++readIndex;
            NSRange nameRange = NSMakeRange(readIndex, nameLength);
            YKFAssertAbortInit([responseData ykf_containsRange:nameRange]);
            
            NSData *nameData = [responseData subdataWithRange:nameRange];
            credentialResult.key = [[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding];
            
            readIndex += nameLength;
            YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
            
            UInt8 responseTag = responseBytes[readIndex];
            switch (responseTag) {
                case YKFKeyOATHCalculateAllResponseHOTPTag:
                    credentialResult.type = YKFOATHCredentialTypeHOTP;
                    break;
                    
                case YKFKeyOATHCalculateAllResponseFullResponseTag:
                case YKFKeyOATHCalculateAllResponseTruncatedResponseTag:
                case YKFKeyOATHCalculateAllResponseTouchTag:
                    credentialResult.type = YKFOATHCredentialTypeTOTP;
                    break;
                
                default:
                    credentialResult.type = YKFOATHCredentialTypeUnknown;
            }
            YKFAssertAbortInit(credentialResult.type != YKFOATHCredentialTypeUnknown);
            
            ++readIndex;
            YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
            
            UInt8 responseLength = responseBytes[readIndex];
            YKFAssertAbortInit(responseLength > 0);
            
            ++readIndex;
            YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
            
            UInt8 digits = responseBytes[readIndex];
            YKFAssertAbortInit(digits == 6 || digits == 7 || digits == 8);
            
            // Parse the period, account and issuer from the key.
            
            NSString *credentialKey = credentialResult.key;
            NSUInteger period = 0;
            NSString *issuer = nil;
            NSString *account = nil;
            NSString *label = nil;
            
            [credentialKey ykf_OATHKeyExtractPeriod:&period issuer:&issuer account:&account label:&label];
            
            credentialResult.issuer = issuer;
            credentialResult.account = account;
            if (credentialResult.type == YKFOATHCredentialTypeTOTP) {
                credentialResult.period = period ? period : YKFOATHCredentialCalculateResultDefaultPeriod;
            }
            
            // Parse the OTP value when TOTP and touch is not required.
            
            if (credentialResult.type == YKFOATHCredentialTypeTOTP && responseTag != YKFKeyOATHCalculateAllResponseTouchTag) {
                ++readIndex;
                YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
                
                UInt8 otpBytesLength = responseLength - 1;
                YKFAssertAbortInit(otpBytesLength == 4);
                
                NSString *otp = [responseData ykf_parseOATHOTPFromIndex:readIndex digits:digits];
                YKFAssertAbortInit(otp.length == digits);
                
                credentialResult.otp = otp;
                
                readIndex += otpBytesLength; // Jump to the next extry.
            } else {
                // No result for TOTP with touch or HOTP
                if (credentialResult.type == YKFOATHCredentialTypeTOTP) {
                    credentialResult.requiresTouch = YES;
                }
                ++readIndex;
            }
            
            // Calculate validity
            
            if (credentialResult.type == YKFOATHCredentialTypeTOTP && responseTag != YKFKeyOATHCalculateAllResponseTouchTag) {
                NSUInteger timestampTimeInterval = [timestamp timeIntervalSince1970]; // truncate to seconds
                
                NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:timestampTimeInterval - timestampTimeInterval % credentialResult.period];
                credentialResult.validity = [[NSDateInterval alloc] initWithStartDate:startDate duration:credentialResult.period];
            } else {
                credentialResult.validity = [[NSDateInterval alloc] initWithStartDate:timestamp endDate:[NSDate distantFuture]];
            }                        
            
            [responseCredentials addObject:credentialResult];
        }
        self.credentials = [responseCredentials copy];
    }
    return self;
}

@end
