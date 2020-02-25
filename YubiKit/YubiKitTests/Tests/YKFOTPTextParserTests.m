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

#import <XCTest/XCTest.h>

#import "YKFTestCase.h"
#import "YKFOTPTextParser.h"

@interface YKFOTPTextParserTests: YKFTestCase

@property (nonatomic) YKFOTPTextParser *textParser;

@end

@implementation YKFOTPTextParserTests

- (void)setUp {
    [super setUp];
    YKFOTPTokenValidator *tokenVlaidator = [[YKFOTPTokenValidator alloc] init];
    self.textParser = [[YKFOTPTextParser alloc] initWithValidator:tokenVlaidator];
}

- (void)tearDown {
    self.textParser = nil;
    [super tearDown];
}

#pragma mark - Valid Yubico OTP URI tests

- (void)test_WhenPayloadIsTextWithYubicoOTP_OTPAndTextAreParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *payload = @"en-US\\some/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    
    NSString *token = [self.textParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP token not correctly parsed.");
    
    NSString *text = [self.textParser textFromPayload:payload];
    XCTAssert([text isEqualToString:payload], @"Text metadata not correctly parsed.");
}

- (void)test_WhenPayloadIsOnlyYubicoOTP_OnlyOTPIsParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *payload = expectedToken;
    
    NSString *token = [self.textParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP token not correctly parsed.");
    
    NSString *text = [self.textParser textFromPayload:expectedToken];
    XCTAssert([text isEqualToString:payload], @"Text metadata not correctly parsed.");
}

#pragma mark - Valid HOTP URI tests

- (void)test_WhenPayloadIsTextWithHOTP_TextAndOTPAreParsed {
    NSString *expectedToken = @"12345678";
    NSString *payload = @"en-US\\some/12345678";

    NSString *token = [self.textParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP token not correctly parsed.");
    
    NSString *text = [self.textParser textFromPayload:payload];
    XCTAssert([text isEqualToString:payload], @"Text metadata not correctly parsed.");
}

- (void)test_WhenPayloadIsOnlyHOTP_OnlyOTPIsParsed {
    NSString *expectedToken = @"12345678";
    NSString *payload = expectedToken;
    
    NSString *token = [self.textParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP token not correctly parsed.");
    
    NSString *text = [self.textParser textFromPayload:payload];
    XCTAssert([text isEqualToString:payload], @"Text metadata not correctly parsed.");
}

@end
